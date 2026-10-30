import csv,json,html,statistics,collections
from decimal import Decimal as D
from pathlib import Path
OUT=Path(__file__).parent
sources={
 'products':'/Users/mike/Downloads/top_products_by_units_sold-2026-10-28_11-56-51.csv',
 'aov':'/Users/mike/Downloads/average_order_value-2026-10-28_11-58-45.csv',
 'sales_all':'/Users/mike/Downloads/sales_over_time-2026-10-28_12-00-46.csv',
 'sales_orders':'/Users/mike/Downloads/sales_over_time-2026-10-28_12-02-01.csv',
 'orders':'/Users/mike/Downloads/Medito-orders_export-2026-10-28_12-03-23.csv'}
def read(p):
 with open(p,encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def num(x):return D(x or '0')
raw=read(sources['orders']); order=[x for x in raw if x['type']=='Order' and x['date']>='2026-01-01' and x['date']<'2026-10-29']; valid=[x for x in order if x['status']!='Canceled']
merch=[num(x['merchandise'])-num(x['discount']) for x in valid]
checkout=[num(x['merchandise'])+num(x['donation'])+num(x['shipping'])+num(x['taxes'])-num(x['discount']) for x in valid]
parent_rows=[x for x in read(sources['products']) if ' - ' not in x['product']]
parents=[]
for x in parent_rows:
 y={'product':html.unescape(x['product']),**{k:float(num(v)) for k,v in x.items() if k!='product'}}
 p=y['product'].lower()
 y['category']='T-shirts' if ('t-shirt' in p) else 'Prints' if p.endswith('print') else 'Stickers' if ('sticker' in p) else 'Mugs' if ('mug' in p) else 'Caps' if ('cap' in p) else 'Candles' if ('candle' in p) else 'Blankets' if ('blanket' in p) else 'Gift cards'
 y['profit_per_unit']=round(y['profit']/y['units_sold'],2); y['profit_to_product_revenue_pct']=round(100*y['profit']/y['net_sales'],2)
 parents.append(y)
cat={}
for x in parents:
 c=cat.setdefault(x['category'],{'category':x['category'],'units':0,'revenue':0,'profit':0})
 c['units']+=x['units_sold'];c['revenue']+=x['net_sales'];c['profit']+=x['profit']
for c in cat.values():
 c['profit_per_unit']=round(c['profit']/c['units'],2);c['margin_pct']=round(100*c['profit']/c['revenue'],2)
for c in cat.values():
 for k in ['revenue','profit']:c[k]=round(c[k],2)
bycountry=collections.Counter(x['shipping_country'] or 'Unknown' for x in valid)
bins=[('Under $20',0,20),('$20–under $30',20,30),('$30–under $40',30,40),('$40–under $60',40,60),('$60+',60,1e9)]
result={'period':'2026-01-01 to 2026-10-28 inclusive (UTC export timestamps)','sources':sources,'record_checks':{'raw_export_rows':len(raw),'YTD_order_records':len(order),'YTD_canceled':len(order)-len(valid),'YTD_non_canceled':len(valid),'unique_order_ids':len(set(x['id'] for x in valid)),'parent_product_rows':len(parents)},'spend':{'orders':len(valid),'mean_merchandise':float(sum(merch)/len(merch)),'median_merchandise':float(statistics.median(merch)),'mean_checkout':float(sum(checkout)/len(checkout)),'median_checkout':float(statistics.median(checkout)),'merchandise_total':float(sum(merch)),'checkout_total':float(sum(checkout)),'shipping_total':float(sum(num(x['shipping']) for x in valid)),'tax_total':float(sum(num(x['taxes']) for x in valid)),'donation_total':float(sum(num(x['donation']) for x in valid)),'refunded_total':float(sum(num(x['refunded']) for x in valid)),'percent_orders_merch_at_least_40':100*sum(x>=40 for x in merch)/len(merch),'percent_orders_merch_at_least_60':100*sum(x>=60 for x in merch)/len(merch),'percent_orders_merch_at_least_80':100*sum(x>=80 for x in merch)/len(merch)},'spend_distribution':[{'band':label,'orders':sum(lo<=x<hi for x in merch)} for label,lo,hi in bins],'categories':sorted(cat.values(),key=lambda x:-x['revenue']),'products':parents,'countries':[{'country':k,'orders':v} for k,v in bycountry.most_common()],'monthly_aov':read(sources['aov']),'monthly_sales_orders':read(sources['sales_orders']),'limitations':['Canceled orders excluded from spend analysis; type Your order (creator/sample) excluded.','Order export reports monetary amounts without currency column; USD is the Fourthwall admin display currency for this run.','Product CSV includes parent and variant rows; parent rows only selected by absence of the export variant separator (space-hyphen-space). Parent rows reconcile to UI summary; archived/current duplicate names kept as separate product rows.','Observed sales reflect availability and promotion; no product-level exposure or conversion denominators.','No causal price elasticity or evidence of demand for unsold premium garments.','Profit fields are provider-reported per-product contribution after payment fees, not business-wide profit after overhead.','Only aggregate or anonymized monetary data enters report; raw customer contact/address records stay in local export.']}
result['reconciliation']={'product_units':sum(x['units_sold'] for x in parents),'product_revenue':round(sum(x['net_sales'] for x in parents),2),'product_profit':round(sum(x['profit'] for x in parents),2),'product_order_incidences':sum(x['orders'] for x in parents),'weighted_margin_pct':100*sum(x['profit'] for x in parents)/sum(x['net_sales'] for x in parents)}
(OUT/'reviewed-sales.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k not in ['products','monthly_aov','monthly_sales_orders','sources','limitations']},indent=2))
