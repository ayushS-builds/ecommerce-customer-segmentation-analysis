#IMPORTING LIBRARIES
import pandas as pd
import psycopg2
import matplotlib.pyplot as plt
import seaborn as sns

#ESTABLISHING CONNECTION WITH POSTGRE
conn = psycopg2.connect(
    host="localhost",
    database="ecommerce",
    user="postgres",
    password="Ayush@2004"
)

print("Connected successfully!")

#RUNNING SQL QUERY IN PYTHON
query = """
WITH max_date AS (
    SELECT MAX(order_purchase_timestamp)::date AS max_dt FROM orders
)
SELECT 
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS frequency,
    SUM(oi.price) AS monetary,
    m.max_dt - MAX(o.order_purchase_timestamp)::date AS recency_days,
    CASE 
        WHEN m.max_dt - MAX(o.order_purchase_timestamp)::date > 180 
            THEN 'High Risk'
        WHEN m.max_dt - MAX(o.order_purchase_timestamp)::date <= 180 
             AND COUNT(DISTINCT o.order_id) <= 2 
            THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_segment

FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
CROSS JOIN max_date m

GROUP BY c.customer_unique_id, m.max_dt
"""
#LOADING DATA INTO DATAFRAMES
df = pd.read_sql(query, conn)

#VIEWING DATA
print(df.head()) # SHOWS ONLY FIRST 5 DATA
print(df.shape) #SHOWS ROWS AND COLUMNS

#BASIC ANALYSIS
print(df['risk_segment'].value_counts()) #COUNTS CUSTOMERS BY RISK SEGMENTS
print(df['risk_segment'].value_counts(normalize=True) * 100) #GIVES % DISTRIBUTION
print(df.groupby('risk_segment')['monetary'].sum()) #REVENUE BY SEGMENT
print(df.groupby('risk_segment')['monetary'].mean()) #AVERAGE SPEND PER CUSTOMER
print(df.groupby('risk_segment')['frequency'].mean()) #FREQUENCY ANALYSIS
print(df.groupby('risk_segment')['recency_days'].mean()) #RECENCY ANALYSIS
top_customers = df.sort_values(by='monetary', ascending=False).head(10)
print(top_customers) #TOP CUSTOMERS

#VISUALIZATION + ANALYSIS
df.groupby('risk_segment')['monetary'].sum().plot(kind='bar')
plt.title("Revenue by Risk Segment")
plt.show() # REVENUE BY SEGMENT

sns.boxplot(x='risk_segment', y='frequency', data=df)
plt.title("Frequency Distribution")
plt.show() # FREQUENCY DISTRIBUTION

# ML CONCEPTS
# =========================
# MACHINE LEARNING (K-MEANS)
# =========================

# Step 1: Select features
X = df[['recency_days', 'frequency', 'monetary']]

# Step 2: Scale data
from sklearn.preprocessing import StandardScaler
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# Step 3: Apply K-Means
from sklearn.cluster import KMeans
kmeans = KMeans(n_clusters=3, random_state=42)

df['cluster'] = kmeans.fit_predict(X_scaled)

# Step 4: Check cluster results
print(df.groupby('cluster')[['recency_days','frequency','monetary']].mean())

# Step 5: Visualize clusters
sns.scatterplot(
    x='recency_days',
    y='monetary',
    hue='cluster',
    data=df
)
plt.title("Customer Clustering (K-Means)")
plt.show()

#CHURN PREDICTION (SIMPLE ML CLASSIFICATION)

# STEP 1 - CREATE TARGET COLUMN
df['churn'] = df['risk_segment'].apply(lambda x: 1 if x == 'High Risk' else 0)

# STEP 2 - FEATURES
# X = df[['recency_days', 'frequency', 'monetary']] GIVING 100 % ACCURACY BECAUSE OF RECENCY
X = df[['frequency', 'monetary']]
y = df['churn']

# STEP 3 - TRAIN - TEST SPLIT
from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# STEP 4 - TRAIN MODEL
from sklearn.linear_model import LogisticRegression
model = LogisticRegression()
model.fit(X_train, y_train)

# STEP 5 - PREDICTIONS
y_pred = model.predict(X_test)

# STEP 6 - ACCURACY
from sklearn.metrics import accuracy_score
print("Accuracy:", accuracy_score(y_test, y_pred))

# STEP 7 - CONFUSION MATRIX
from sklearn.metrics import confusion_matrix
print(confusion_matrix(y_test, y_pred))

print(model.coef_) # SHOWS WHICH FACTORS AFFECTS CHURN MOST

# VISUALIZATION
# ========================================================

# RECENCY DISTRIBUTION
plt.figure()
df['recency_days'].hist(bins=50)
plt.title("Recency Distribution")
plt.xlabel("Days Since Last Purchase")
plt.ylabel("Number of Customers")
plt.show()

# REVENUE BY RISK SEGMENT
df.groupby('risk_segment')['monetary'].sum().sort_values().plot(kind='barh')
plt.title("Revenue Contribution by Risk Segment")
plt.xlabel("Total Revenue")
plt.ylabel("Risk Segment")
plt.show()

# FREQUENCY VS MONETARY
plt.figure()
plt.scatter(df['frequency'], df['monetary'])
plt.title("Frequency vs Monetary")
plt.xlabel("Number of Orders")
plt.ylabel("Total Spend")
plt.show()

# Recency vs Frequency (customer behavior)
plt.figure()
plt.scatter(df['recency_days'], df['frequency'])
plt.title("Recency vs Frequency")
plt.xlabel("Recency (days)")
plt.ylabel("Frequency")
plt.show()

# Cluster-wise comparison (VERY IMPRESSIVE)
df.groupby('cluster')[['recency_days','frequency','monetary']].mean().plot(kind='bar')
plt.title("Cluster Comparison")
plt.ylabel("Average Values")
plt.show()

# HEATMAP (CORRELATION)
import seaborn as sns

sns.heatmap(df[['recency_days','frequency','monetary']].corr(), annot=True)
plt.title("Feature Correlation")
plt.show()

df.to_csv("final_customer_data.csv", index=False) #FOR POWER BI