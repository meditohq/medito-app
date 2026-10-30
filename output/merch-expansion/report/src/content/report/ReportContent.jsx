import React from "react";
import { DataComponent, DataTable, EvidenceChart, ReportSection, RichNarrative, useDataApp } from "../../data-app-public.jsx";

const dollars = value => new Intl.NumberFormat("en-US", {style:"currency", currency:"USD", maximumFractionDigits:2}).format(value);
const categoryColumns = [
 {field:"category",label:"Category"}, {field:"units",label:"Units"},
 {field:"revenue",label:"Product sales",renderCell:v=>dollars(v)},
 {field:"profit",label:"Product profit",renderCell:v=>dollars(v)},
 {field:"profit_per_unit",label:"Profit / unit",renderCell:v=>dollars(v)},
 {field:"margin_pct",label:"Profit / sales",renderCell:v=>`${v.toFixed(1)}%`},
];
const draftColumns = [
 {field:"product",label:"Draft product"}, {field:"price",label:"Price",renderCell:v=>dollars(v)},
 {field:"baseCost",label:"Base cost",renderCell:v=>dollars(v)},
 {field:"spread",label:"Before-fee spread",renderCell:v=>dollars(v)},
 {field:"state",label:"State"}
];

export function ReportContent() {
 const {snapshot,reviewedPeriodRows,visible,canEdit,mode,appTitle,setAppTitle}=useDataApp();
 const summary=reviewedPeriodRows("spend_summary"), distribution=reviewedPeriodRows("spend_distribution");
 const categories=reviewedPeriodRows("category_results"), products=reviewedPeriodRows("product_results");
 const pricing=reviewedPeriodRows("pricing_scenario"), drafts=reviewedPeriodRows("new_drafts");
 const headline=`## Executive Summary\n\n- **Build around garments.** T-shirts generated **$4,590 in product sales and $1,695 in reported product profit**, about 63% of both. A premium logo tee is the closest extension of existing demand.\n- **Keep an accessible entry price.** Across 243 non-canceled customer orders, median merchandise spend was **$28** and average merchandise spend was **$29.99**. The $41.78 average checkout includes shipping, tax, and donations.\n- **Treat higher prices as tests.** Only **11 of 243 orders (4.5%)** contained $60 or more in merchandise. The $58 hoodie adds a useful premium option, but its demand is unproven.\n- **Improve contribution through simpler production.** Unplug Front Logo sold 14 units and earned $202 in reported profit, close to Cat Reflections' $211 from 24 units. A restrained exact-logo range offers a plausible way to improve the mix without inventing more artwork.`;
 return <article className="report-content" aria-label="Medito merchandise decision report">
  <header className="report-hero">
   <h1 data-data-app-title contentEditable={canEdit&&mode==="edit"} suppressContentEditableWarning onBlur={canEdit&&mode==="edit"?e=>setAppTitle(e.currentTarget.textContent.trim()||appTitle):undefined}>{appTitle}</h1>
  </header>
  {visible("merch-summary")&&<ReportSection id="merch-summary" title="Executive Summary" queryId="spend_summary" queryIds={["spend_summary","category_results","product_results"]} sourceRowsByQuery={{spend_summary:summary,category_results:categories,product_results:products}} showHeading={false}>
   <RichNarrative id="merch-summary:body" value={headline} label="Edit executive summary"/>
  </ReportSection>}
  <section className="report-section">
   <ReportSection id="merch-spend" title="Most baskets remain close to one T-shirt" queryId="spend_summary" sourceRows={summary} showHeading={false}>
    <RichNarrative id="merch-spend:body" value={`## Most baskets remain close to one T-shirt\n\nAbout **71% of orders contained less than $30 in merchandise**. Another 31 orders fell between $30 and $40. That supports a $34 heavyweight logo tee as a manageable step up, while a $58 hoodie should remain an optional premium tier.\n\nShipping averaged **$7.28 per order**, before tax. Show garment quality and fit clearly enough to justify the total checkout price; avoid assuming a $42 checkout means customers already spend $42 on the garment itself.`}/>
   </ReportSection>
   <EvidenceChart id="merch-spend-bars" queryId="spend_distribution" title="Merchandise spend per customer order" spec={{type:"bar",x:"band",y:"orders",valueDecimals:0,colors:["#16766E"]}} rows={distribution} sourceRows={distribution} height={320} description="243 non-canceled customer orders, 1 January–28 October 2026. Excludes shipping, tax, and donations."/>
  </section>
  <section className="report-section">
   <ReportSection id="merch-category-story" title="T-shirts earn most of the profit; stickers remain useful additions" queryId="category_results" sourceRows={categories} showHeading={false}>
    <RichNarrative id="merch-category-story:body" value={`## T-shirts earn most of the profit; stickers remain useful additions\n\nT-shirts sold **169 units** and generated **$10.03 reported product profit per unit**. Prints sold 71 units but returned $4.39 each. Stickers sold 70 units and returned $4.61 each, with a 58.3% profit-to-product-sales ratio. Keep them as accessible additions rather than expecting them to replace garment contribution.\n\nThe embroidered logo cap sold **8 units this year**, a modest sign that some supporters want simple branding. The single $69 blanket sale does not establish broad appetite for expensive merchandise.`}/>
   </ReportSection>
   <EvidenceChart id="merch-profit-bars" queryId="category_results" title="Reported product profit by category" spec={{type:"horizontalBar",x:"category",y:"profit",currency:"USD",valueDecimals:2,colors:["#16766E"]}} rows={categories} sourceRows={categories} height={390} description="Product contribution reported by Fourthwall; business overhead is not deducted."/>
   <DataComponent id="merch-category-table" title="Sales and contribution by product category" queryId="category_results" kind="table" displayRows={categories} sourceRows={categories}>
    <DataTable rows={categories} columns={categoryColumns} searchable={false} caption="2026 category performance"/>
   </DataComponent>
  </section>
  <section className="report-section">
   <ReportSection id="merch-pricing" title="A $30 Cat Reflections test is more defensible than a store-wide price rise" queryId="pricing_scenario" queryIds={["pricing_scenario","product_results"]} sourceRowsByQuery={{pricing_scenario:pricing,product_results:products.filter(x=>["Cat Reflections T-Shirt","Unplug Front Logo T-Shirt"].includes(x.product))}} showHeading={false}>
    <RichNarrative id="merch-pricing:body" value={`## A $30 Cat Reflections test is more defensible than a store-wide price rise\n\nCat Reflections sold **24 units** this year. A move from its current **$28 to $30** would increase the displayed price-minus-production spread from **$10.55 to $12.55**, before payment fees. At unchanged production cost, keeping about **84% of unit sales** would preserve that spread in total.\n\nThis is an accounting sensitivity, not an estimate of how customers will react. Keep the current core range accessible and test one well-established design first. Compare product profit per qualified visit, conversion, and refunds across comparable traffic before expanding the rise. **Existing live prices have not been changed.**\n\nPrice variation by size and actual payment fees matter: the provider's displayed spread is not the same as realized order profit.`}/>
   </ReportSection>
  </section>
  <section className="report-section">
   <ReportSection id="merch-drafts-story" title="Use the exact Medito mark on better blanks" queryId="new_drafts" sourceRows={drafts} showHeading={false}>
    <RichNarrative id="merch-drafts-story:body" value={`## Use the exact Medito mark on better blanks\n\nThe new range uses the existing brand mark, small white embroidery, restrained garment colors, and no AI illustrations. Quality comes from the blank and the execution: a 6.1 oz garment-dyed heavyweight tee, a premium embroidered hoodie, and an everyday cuffed beanie.\n\nAll three are **hidden drafts**, so the designs and sample quality can be reviewed before launch. The $26 beanie keeps a simple logo option close to the existing $28 median basket. Preserve any larger-size production surcharges. The economics below are base-size price-minus-production spreads and exclude payment fees, refunds, marketing, and overhead.`}/>
   </ReportSection>
   <DataComponent id="merch-drafts-table" title="New product draft economics" queryId="new_drafts" kind="table" displayRows={drafts} sourceRows={drafts}>
    <DataTable rows={drafts} columns={draftColumns} searchable={false} caption="New hidden product draft economics"/>
   </DataComponent>
   <RichNarrative id="merch-draft-links" value={`[Review heavyweight logo tee](https://admin.fourthwall.com/store/medito-foundation/products/f8b24913-6408-444a-a2a8-0113dad64b06/preview) · [Review embroidered logo hoodie](https://admin.fourthwall.com/store/medito-foundation/products/8c87b163-2ee5-49d5-b160-9d82f22be020/preview) · [Review everyday logo beanie](https://admin.fourthwall.com/store/medito-foundation/products/43078740-339e-40a3-b115-73ac7ff92d93/preview)`}/>
  </section>
  <ReportSection id="merch-evidence-notes" title="Evidence and limits" queryId="spend_summary" queryIds={["spend_summary","product_results","new_drafts"]} sourceRowsByQuery={{spend_summary:summary,product_results:products,new_drafts:drafts}} showHeading={false}>
   <RichNarrative id="merch-evidence-notes:body" value={`## Evidence and limits\n\nOrders and product exports cover **1 January–28 October 2026**; October is incomplete. Spend analysis excludes six canceled orders and creator/sample orders, leaving 243 distinct customer orders. Product parent rows reconcile to **368 units, $7,288.35 product sales, and $2,698.82 product profit**. Variant rows are not counted twice.\n\nProduct-order counts overlap across products and are not distinct store orders. Product profit is separate from add-on donations: $71.64 in order donations explains the difference between $2,770.46 order profit and $2,698.82 product profit. Category margins are recomputed from summed profit and sales, not averaged from displayed percentages.\n\nThese totals show purchases, not preference after equal exposure. Product age, promotion, stock availability, and visits were not controlled. The exports cannot prove premium-garment demand or price elasticity. Some non-canceled orders have partial refunds; spend describes booked merchandise at order time, while the provider's product-profit figures are retained as reported.\n\nCustomer contact and address data are excluded from this report. Detailed definitions, files, transformations, and original Fourthwall links are available through each chart's source menu.`}/>
  </ReportSection>
 </article>;
}
