import pandas as pd

df = pd.read_csv("data/saturn_active_nodes.csv", header=None, parse_dates=[0])
print(df)

res = df.plot(x=0, y=1).get_figure()
res.savefig("data/saturn_active_nodes.png")
