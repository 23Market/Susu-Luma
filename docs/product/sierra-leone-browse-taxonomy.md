# Sierra Leone Browse Taxonomy and Seed Catalogue

Status: product design proposal; sample entries are illustrative only and must not be presented as verified suppliers, inventory, prices, or offers.

## Source basis

Prepared using the uploaded SLIEPA brochure, *Invest in Agriculture in Sierra Leone*. Its pages 8–9 identify food crops (including rice, cassava, groundnuts), cash crops (cocoa, coffee, oil palm), horticulture (pineapple, banana, mango, avocado, tomato, pepper, eggplant), livestock, and agro-inputs (fertilizer, seeds, tools, agrochemicals, veterinary inputs, animal feed, and post-harvest machinery). Page 7 describes road and port infrastructure relevant to logistics. Brochure statistics and policy dates are historical and must be verified before reuse.

## Browse category taxonomy

### Agriculture
- Food Crops: paddy rice, milled rice, cassava, cassava flour, gari, groundnuts.
- Cash Crops: cocoa beans, coffee beans, palm kernels, oil-palm fruit.
- Horticulture: pineapple, banana, mango, avocado, tomato, pepper, eggplant.
- Agro-Inputs: seeds, fertilizer, approved crop-protection products, hand tools, veterinary inputs, animal feed.
- Farm Machinery: irrigation pumps, tractors, threshers, harvest tools.
- Agro-Processing: rice mills, cassava graters/presses, dryers, palm-oil presses, packaging equipment.
- Livestock & Veterinary: animal feed, poultry inputs, veterinary supplies, livestock and processing equipment.
- Fisheries & Seafood: fresh fish, fishing nets, ice boxes, cold-storage equipment.
- Forestry & Timber: sawn timber and wood-processing equipment.

### Industrial and cross-sector supply
- Construction: cement, roofing sheets, blocks, aggregates, plumbing and electrical supplies.
- Metals: reinforcing bars, sheet metal, fasteners, fabrication stock.
- Mining & Minerals: permitted industrial mineral and mining supply categories; listing and supplier eligibility require compliance review.
- Equipment & Power: generators, workshop tools, compressors, industrial spares.
- Energy & Solar: solar panels, inverters, batteries, mounting systems.
- Water & Sanitation: storage tanks, pumps, filtration and sanitation supplies.
- Packaging & Supplies: sacks, crates, cartons, food-safe containers, pallets.
- Transport & Logistics: freight, warehousing, cold chain and last-mile delivery services.
- Local Crafts & Textiles: woven goods, textiles and locally made products.

## Seed catalogue examples

All supplier names below are placeholders. Do not label them verified and do not invent prices.

| Category | Example listing | Unit | Example location |
|---|---|---|---|
| Food Crops | Paddy rice | 50 kg bag | Bombali District |
| Food Crops | Groundnuts | 25 kg sack | Tonkolili District |
| Cash Crops | Coffee beans | kg | Kailahun District |
| Cash Crops | Cocoa beans | kg | Kono District |
| Horticulture | Pineapples | crate | Western Area Rural |
| Horticulture | Tomatoes | crate | Bo District |
| Agro-Inputs | Fertilizer | 50 kg bag | Bombali District |
| Farm Machinery | Irrigation pump | unit | Freetown |
| Livestock & Veterinary | Animal feed | 25 kg bag | Kenema District |
| Agro-Processing | Rice milling machine | machine | Bo District |
| Fisheries & Seafood | Fresh fish | crate | Western Area |
| Forestry & Timber | Sawn timber | cubic metre | Kenema District |
| Construction | Portland cement | bag | Western Area |
| Energy & Solar | Solar panel | panel | Freetown |
| Water & Sanitation | Water storage tank | tank | Bombali District |
| Packaging & Supplies | Reusable produce crate | crate | Freetown |

## Listing fields to standardize

Required before publication:
- title, category, description
- organization_id / supplier profile, supplier verification status
- district, optional locality
- quantity_unit, optional minimum_order_quantity
- price_mode (quote_only, indicative, or fixed); price_amount and currency_code only when appropriate
- availability, lead_time_days
- listing status and moderation metadata
- created/updated timestamps

Recommended for agricultural listings:
- crop/commodity and variety
- grade/quality, moisture or other relevant specification where applicable
- harvest season / stock date
- packaging type and weight
- origin district
- storage requirements and shelf-life where applicable
- minimum order and volume availability
- pickup/delivery options and destination coverage
- relevant certification or permits, when applicable

## Search and filtering

- Search title, description, category, supplier display name, district, locality and commodity aliases.
- Filters: category/subcategory, district, availability, quote/fixed price mode, minimum order, verified supplier, delivery available.
- Never infer that a supplier is verified from sample data. Only show a verified badge from the authoritative verification status.
- Keep all sample/demo listings visually labelled as illustrative and separate from published marketplace listings.

## Safety and data quality gates

- Replace every placeholder supplier with a real organization that has consented to listing.
- Confirm product existence, stock, units, minimum order, origin and delivery terms before publishing.
- Do not fabricate prices, certifications, supplier contacts or verification badges.
- Review controlled/agrochemical products, minerals and other regulated categories for applicable laws and platform policy before enabling listings.
- Use Sierra Leone's current approved currency configuration and explicit currency per price; do not silently convert.
- The brochure is a sector discovery reference, not a live directory, price source or current statistics source.
