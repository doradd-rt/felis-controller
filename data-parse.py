import json

json_file_path = './static/test-opt.json'

with open(json_file_path, 'r') as json_file:
    json_data = json_file.read()

data_obj = json.loads(json_data)

summary_ls = []
for record in data_obj:
    summary = {
        "cpu": record["cpu"],
        "attribute": record["attribute"].split("_")[1],
        "throughput": record["throughput"],
        "symbol": record["symbol"]
    }
    if summary["cpu"] == 24:
        summary_ls.append(summary)
        #print(summary)

sorted_summary_list = sorted(summary_ls, key=lambda x: x["attribute"])
for ent in sorted_summary_list:
    print(ent)
