from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import re
from datetime import datetime
import asyncio
from concurrent.futures import ThreadPoolExecutor

_executor = ThreadPoolExecutor(max_workers=2)

try:
    import ollama
    ollama.chat(model="mistral", messages=[{"role": "user", "content": "hi"}])
    LLM_READY = True
    print("Mistral via Ollama loaded successfully.")
except Exception as e:
    print(f"Mistral/Ollama not available: {e}")
    LLM_READY = False

try:
    from pdfminer.high_level import extract_text as pdf_extract_text
    PDF_SUPPORT = True
except ImportError:
    PDF_SUPPORT = False
    print("WARNING: pdfminer.six not installed. Run: pip install pdfminer.six")

app = FastAPI(title="AI Purchase Analyzer")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

#I tried to include as many variations of popular companies as I could but this is not exhaustive
VENDOR_ALIASES = { 
    # Consumer
    "best buy": "BestBuy",
    "bestbuy": "BestBuy",
    "home depot": "HomeDepot",
    "homedepot": "HomeDepot",
    "the home depot": "HomeDepot",
    "mcdonald's": "McDonalds",
    "mcdonalds": "McDonalds",
    "mcdonald": "McDonalds",
    "starbucks coffee": "Starbucks",
    "nike.com": "Nike",
    "amazon.com": "Amazon",
    "costco wholesale": "Costco",
    "walmart supercenter": "Walmart",
    "wal-mart": "Walmart",
    "staples": "Staples",
    "office depot": "OfficeDepot",
    "officedepot": "OfficeDepot",
    "microsoft": "Microsoft",
    "newegg": "Newegg",
    "b&h": "B&H Photo",
    "b&h photo": "B&H Photo",
    "adorama": "Adorama",
    "dell": "Dell",
    "lenovo": "Lenovo",
    "hp": "HP",

    # Electronics
    "mouser electronics": "Mouser",
    "mouser": "Mouser",
    "digikey": "DigiKey",
    "digi-key": "DigiKey",
    "digi-key electronics": "DigiKey",
    "newark": "Newark",
    "newark electronics": "Newark",
    "element14": "Newark",
    "arrow electronics": "Arrow",
    "arrow": "Arrow",
    "avnet": "Avnet",
    "avnet electronics": "Avnet",
    "rs components": "RS Components",
    "rs-components": "RS Components",
    "allied electronics": "Allied Electronics",
    "allied": "Allied Electronics",
    "future electronics": "Future Electronics",
    "adafruit": "Adafruit",
    "adafruit industries": "Adafruit",
    "sparkfun": "SparkFun",
    "sparkfun electronics": "SparkFun",
    "pololu": "Pololu",
    "pololu corporation": "Pololu",
    "jameco": "Jameco",
    "jameco electronics": "Jameco",
    "sager electronics": "Sager",
    "sager": "Sager",
    "tti": "TTI",
    "tti inc": "TTI",
    "Rochester electronics": "Rochester Electronics",

    # Industrial/Hardware 
    "mcmaster-carr": "McMaster-Carr",
    "mcmaster carr": "McMaster-Carr",
    "mcmaster": "McMaster-Carr",
    "grainger": "Grainger",
    "w.w. grainger": "Grainger",
    "ww grainger": "Grainger",
    "zoro.com": "Zoro",
    "zoro": "Zoro",
    "zoro tools": "Zoro",
    "fastenal": "Fastenal",
    "fastenal company": "Fastenal",
    "uline": "Uline",
    "uline.com": "Uline",
    "msc industrial": "MSC Industrial",
    "msc direct": "MSC Industrial",
    "mscdirect": "MSC Industrial",
    "msc": "MSC Industrial",
    "motion industries": "Motion Industries",
    "motion": "Motion Industries",
    "nnu": "NNU",
    "northern tool": "Northern Tool",
    "northern tool + equipment": "Northern Tool",
    "harbor freight": "Harbor Freight",
    "harbor freight tools": "Harbor Freight",
    "global industrial": "Global Industrial",
    "global industrial company": "Global Industrial",
    "airgas": "Airgas",
    "airgas usa": "Airgas",
    "praxair": "Praxair",
    "linde": "Linde",
    "acklands-grainger": "Grainger Canada",
    "toolup": "ToolUp",
    "toolup.com": "ToolUp",
    "enco": "Enco",
    "use-enco": "Enco",
    "travers tool": "Travers Tool",
    "travers": "Travers Tool",
    "j&l industrial": "J&L Industrial",

    # Fasteners
    "bolt depot": "Bolt Depot",
    "boltdepot": "Bolt Depot",
    "boltdepot.com": "Bolt Depot",
    "ace hardware": "Ace Hardware",
    "acehardware": "Ace Hardware",
    "sps technologies": "SPS Technologies",
    "würth": "Wurth",
    "wurth": "Wurth",
    "wurth industry": "Wurth",
    "anixter": "Anixter",
    "wesco": "WESCO",
    "wesco international": "WESCO",

    # Fabrication
    "sendcutsend": "SendCutSend",
    "send cut send": "SendCutSend",
    "sendcutsend.com": "SendCutSend",
    "xometry": "Xometry",
    "xometry.com": "Xometry",
    "protolabs": "Protolabs",
    "proto labs": "Protolabs",
    "protolabs.com": "Protolabs",
    "hubs": "Hubs",
    "hubs.com": "Hubs",
    "3dhubs": "Hubs",
    "fictiv": "Fictiv",
    "fictiv.com": "Fictiv",
    "pcbway": "PCBWay",
    "pcbway.com": "PCBWay",
    "jlcpcb": "JLCPCB",
    "jlcpcb.com": "JLCPCB",
    "oshpark": "OSH Park",
    "osh park": "OSH Park",
    "oshpark.com": "OSH Park",
    "advanced circuits": "Advanced Circuits",
    "4pcb": "Advanced Circuits",
    "sunstone circuits": "Sunstone Circuits",
    "sunstone": "Sunstone Circuits",
    "laserboost": "LaserBoost",
    "emelinc": "EMELinc",
    "eme linc": "EMELinc",
    "shapeways": "Shapeways",
    "shapeways.com": "Shapeways",
    "sculpteo": "Sculpteo",
    "3d systems": "3D Systems",
    "stratasys": "Stratasys",
    "markforged": "Markforged",
    "formlabs": "Formlabs",

    # Materials/Raw Stock
    "onlinemetals": "Online Metals",
    "online metals": "Online Metals",
    "onlinemetals.com": "Online Metals",
    "metals depot": "Metals Depot",
    "metalsdepot": "Metals Depot",
    "metalsdepot.com": "Metals Depot",
    "speedy metals": "Speedy Metals",
    "speedymetals": "Speedy Metals",
    "midwest steel": "Midwest Steel",
    "midwest steel supply": "Midwest Steel",
    "industrial metal supply": "Industrial Metal Supply",
    "ims": "Industrial Metal Supply",
    "tap plastics": "TAP Plastics",
    "tapplastics": "TAP Plastics",
    "mcmaster plastics": "McMaster-Carr",
    "professionalplastics": "Professional Plastics",
    "professional plastics": "Professional Plastics",
    "inventables": "Inventables",
    "inventables.com": "Inventables",

    # Automation/Robotics
    "igus": "Igus",
    "igus inc": "Igus",
    "misumi": "Misumi",
    "misumi usa": "Misumi",
    "misumiusa": "Misumi",
    "servo city": "ServoCity",
    "servocity": "ServoCity",
    "servocity.com": "ServoCity",
    "robotshop": "RobotShop",
    "robotshop.com": "RobotShop",
    "actuonix": "Actuonix",
    "actuonix motion devices": "Actuonix",
    "firgelli": "Firgelli",
    "firgelli automations": "Firgelli",
    "maxon": "Maxon Motor",
    "maxon motor": "Maxon Motor",
    "faulhaber": "Faulhaber",
    "dynamixel": "Dynamixel",
    "robotis": "Robotis",
    "robotis.us": "Robotis",

    # Lab/Medical/Safety
    "mckesson": "McKesson",
    "henry schein": "Henry Schein",
    "fisher scientific": "Fisher Scientific",
    "thermo fisher": "Thermo Fisher",
    "vwr": "VWR",
    "vwr international": "VWR",
    "grainger safety": "Grainger",
    "usp": "USP",
    "ppe headquarters": "PPE HQ",
}


TOTAL_LABELS = [
    r'order\s+total',
    r'invoice\s+total',
    r'grand\s+total',
    r'amount\s+(?:due|charged|paid)',
    r'(?<!\w)total(?!\s+(?:items?|savings?|discount|subtotal|tax|reward|pts|points|before))',
    r'balance\s+due',
    r'charged\s+to',
    r'you\s+(?:paid|owe)',
]

SKIP_LABELS = [
    r'subtotal', r'sub-total', r'sub total',
    r'tax', r'shipping', r'discount', r'savings?',
    r'reward', r'gift\s+card', r'coupon',
    r'estimated', r'unit\s+price', r'each',
    r'membership', r'points', r'cash\s+back',
    r'change\s+due', r'tendered',
]

ORG_NOISE = {
    'solutions', 'limbitless', 'technologies', 'systems', 'industries',
    'enterprises', 'incorporated', 'corporation', 'company', 'associates',
    'group', 'partners', 'services', 'consulting', 'international', 'global',
    'llc', 'inc', 'corp', 'ltd', 'co',
}

FIELD_NOISE = {
    'service', 'center', 'store', 'support', 'team', 'pickup', 'plus',
    'delivery', 'address', 'location', 'account', 'rewards', 'benefit',
    'acct', 'pro', 'executive', 'number', 'type', 'card', 'loyalty',
    'on card', 'attention',
}

NAME_BLOCKLIST = {
    'united states', 'united kingdom', 'new york', 'los angeles', 'san francisco',
    'las vegas', 'free returns', 'ship date', 'order date', 'your order',
    'estimated delivery', 'order type', 'drive thru', 'ship to', 'bill to',
    'order confirmation', 'invoice date', 'ordered by', 'thank you',
    'order number', 'customer service', 'north america', 'south america',
    'new jersey', 'new mexico', 'west virginia', 'rhode island',
}


# FILE EXTRACTION
def extract_text_from_file(file_bytes: bytes, filename: str) -> str:
    if filename.endswith(".txt"):
        return file_bytes.decode("utf-8", errors="ignore")
    elif filename.endswith(".pdf"):
        if not PDF_SUPPORT:
            raise HTTPException(status_code=400, detail="pdfminer.six not installed.")
        import io
        with io.BytesIO(file_bytes) as f:
            return pdf_extract_text(f)
    else:
        raise HTTPException(status_code=400, detail="Only .txt and .pdf files are supported.")


# PRICE EXTRACTION
def extract_all_dollar_amounts(text: str):
    results = []
    pattern = re.compile(
        r'^(?P<label>[^\n\r$]*?)\s*\$?\s*(?P<amount>[\d,]+\.\d{2})\s*$',
        re.MULTILINE | re.IGNORECASE
    )
    for m in pattern.finditer(text):
        label = m.group('label').strip().lower()
        raw   = m.group('amount').replace(',', '')
        try:
            amt = float(raw)
            if amt > 0:
                results.append((label, amt))
        except ValueError:
            pass
    for m in re.finditer(r'^\$([ \d,]+\.\d{2})\s*$', text, re.MULTILINE):
        raw = m.group(1).replace(',', '').strip()
        try:
            amt = float(raw)
            if amt > 0 and not any(abs(a - amt) < 0.001 for _, a in results):
                results.append(('', amt))
        except ValueError:
            pass
    return results


def is_skip_label(label: str) -> bool:
    for pattern in SKIP_LABELS:
        if re.search(pattern, label, re.IGNORECASE):
            return True
    return False


def extract_price(text: str) -> str:
    for pattern in [
        r'(?:paid\s+by\s+(?:credit\s+card|debit|check))\s+(?:USD\s+)?\$?([\d,]+\.\d{2})',
        r'(?:USD|CAD|EUR|GBP)\s+\$([\d,]+\.\d{2})',
        r'(?:invoice\s+total|order\s+total|grand\s+total)\s*:?\s*\$?([\d,]+\.\d{2})',
        r'amount\s+(?:due|paid|charged)\s*:?\s*\$?([\d,]+\.\d{2})',
    ]:
        m = re.search(pattern, text, re.IGNORECASE)
        if m:
            try:
                return f"{float(m.group(1).replace(',', '')):.2f}"
            except ValueError:
                pass

    all_amounts = extract_all_dollar_amounts(text)
    if not all_amounts:
        return ''

    total_candidates = []

    for label, amt in all_amounts:
        if any(re.search(pp, label, re.IGNORECASE) for pp in TOTAL_LABELS) and not is_skip_label(label):
            total_candidates.append(amt)

    for label, amt in all_amounts:
        if label == '':
            total_candidates.append(amt)

    tlines = [l.strip() for l in text.split('\n')]
    for i, tl in enumerate(tlines):
        if re.fullmatch(r'(?:total|amount\s+due|balance\s+due)[:\s]*', tl, re.IGNORECASE):
            for j in range(i + 1, min(i + 8, len(tlines))):
                nl = tlines[j].strip()
                if nl:
                    m = re.match(r'^\$?([\d,]+\.\d{2})$', nl)
                    if m:
                        try:
                            total_candidates.append(float(m.group(1).replace(',', '')))
                        except ValueError:
                            pass
                    break

    if total_candidates:
        return f"{max(total_candidates):.2f}"

    merch_amt = ship_amt = None
    for label, amt in all_amounts:
        if re.search(r'merchandise', label, re.IGNORECASE) and not merch_amt:
            merch_amt = amt
        if re.search(r'shipping', label, re.IGNORECASE) and not ship_amt:
            ship_amt = amt
    if merch_amt and ship_amt:
        return f"{round(merch_amt + ship_amt, 2):.2f}"

    non_skip = [amt for label, amt in all_amounts if not is_skip_label(label)]
    if non_skip:
        return f"{max(non_skip):.2f}"

    return f"{max(amt for _, amt in all_amounts):.2f}"


# DATE EXTRACTION
def extract_date(text: str) -> str:
    candidates = []

    for priority_label in [r'order\s+date', r'purchase\s+date', r'transaction\s+date']:
        m = re.search(priority_label + r'[:\s]+([A-Za-z0-9,\s\/\-\.]+?)(?:\n|$|\|)', text, re.IGNORECASE)
        if m:
            candidates.append(m.group(1).strip())
            break

    lines = [l.strip() for l in text.split('\n')]
    for i, line in enumerate(lines):
        if re.fullmatch(r'order\s+date[:\s]*', line, re.IGNORECASE):
            for j in range(i+1, min(i+12, len(lines))):
                nl = lines[j].strip()
                if nl and re.search(r'([\d]{1,2}[\-\/][A-Za-z\d]|[A-Za-z]{3}[\-\/\s]\d|\d[\-\/]\d{1,2}[\-\/])', nl):
                    candidates.append(nl)
                    break

    for fallback_label in [r'invoice\s+date', r'(?<!ship\s)date']:
        m = re.search(fallback_label + r'[:\s]+([A-Za-z0-9,\s\/\-\.]+?)(?:\n|$|\|)', text, re.IGNORECASE)
        if m:
            candidates.append(m.group(1).strip())

    date_patterns = [
        r'\b(\w+\s+\d{1,2},?\s*\d{4})\b',
        r'\b(\d{1,2}\s+\w+\s+\d{4})\b',
        r'\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})\b',
        r'\b(\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})\b',
    ]
    for pattern in date_patterns:
        for m in re.finditer(pattern, text, re.IGNORECASE):
            candidates.append(m.group(1))

    formats = [
        "%m/%d/%Y", "%m-%d-%Y", "%m/%d/%y",
        "%Y-%m-%d", "%Y/%m/%d",
        "%B %d, %Y", "%B %d %Y", "%b %d, %Y", "%b %d %Y",
        "%d %B %Y", "%d %b %Y",
        "%B %d,%Y", "%b %d,%Y",
        "%d-%b-%y", "%d-%b-%Y",
        "%b-%d-%y", "%b-%d-%Y",
    ]
    for raw in candidates:
        clean = raw.strip().rstrip('.,')
        for fmt in formats:
            try:
                dt = datetime.strptime(clean, fmt)
                if 2000 <= dt.year <= 2030:
                    return dt.strftime("%m/%d/%Y")
            except ValueError:
                continue

    return datetime.today().strftime("%m/%d/%Y")

# VENDOR EXTRACTION (regex + LLM fallback)
def extract_vendor(text: str) -> str:
    text_lower = text.lower()

    for alias, canonical in VENDOR_ALIASES.items():
        if alias in text_lower:
            return canonical

    m = re.search(r'(?:www\.)?([a-zA-Z0-9\-]+)\.(com|net|org|io)', text_lower)
    if m:
        domain = m.group(1).replace('-', ' ').title()
        if len(domain) > 2 and domain.lower() not in {'your', 'our', 'the', 'this', 'http', 'https'}:
            for alias, canonical in VENDOR_ALIASES.items():
                if m.group(1) in alias:
                    return canonical
            return domain

    m = re.search(
        r'(?:vendor|store|merchant|retailer|sold\s+by|from)[:\s]+([A-Z][a-zA-Z0-9\s&\'\-\.]{1,30})',
        text, re.IGNORECASE
    )
    if m:
        return m.group(1).strip().rstrip('.,')

    lines = [l.strip() for l in text.split('\n') if l.strip()]
    for line in lines[:8]:
        if re.search(r'\d{3}[\-\.\s]\d{3}', line):
            continue
        if re.search(r'\d+\s+[A-Z][a-z]+\s+(St|Ave|Rd|Blvd|Dr|Way|Pkwy)', line):
            continue
        if re.search(r'(LLC|Inc|Corp|Ltd|Co\.)', line, re.IGNORECASE):
            name = re.sub(r'(LLC|Inc|Corp|Ltd|Co\.|Supply Company)', '', line, flags=re.IGNORECASE).strip().rstrip('.,')
            if 2 < len(name) < 40:
                return name
        if re.match(r'^[A-Z][A-Z\s&\-\.]{3,30}$', line) and len(line) < 35:
            return line.title()

    if LLM_READY:
        return _llm_extract_vendor(text)

    return ""


def _llm_extract_vendor(raw_text: str) -> str:
    trimmed = trim_receipt(raw_text, "", max_chars=600)
    try:
        response = ollama.chat(
            model="mistral",
            messages=[{"role": "user", "content": (
                f"[INST] Here is the top portion of a receipt or invoice:\n\n"
                f"\"\"\"\n{trimmed}\n\"\"\"\n\n"
                f"What is the vendor, store, or company name that issued this receipt? "
                f"Reply with only the vendor name, nothing else. "
                f"No explanation, no punctuation, just the name. [/INST]"
            )}],
            options={"temperature": 0.1, "stop": ["\n"]}
        )
        vendor = response["message"]["content"].strip().strip('.,')
        if vendor and 2 < len(vendor) < 40 and '\n' not in vendor:
            return vendor
    except Exception:
        pass
    return ""


# PURCHASER EXTRACTION (regex + LLM fallback)
def _is_valid_person_name(name: str) -> bool:
    if not name:
        return False
    if name.lower() in NAME_BLOCKLIST:
        return False
    parts = name.strip().split()
    if len(parts) < 2 or len(parts) > 3:
        return False
    for part in parts:
        if not re.match(r'^[A-Z][a-z]{1,20}$', part):
            return False
    name_lower = name.lower()
    for noise in ORG_NOISE | FIELD_NOISE:
        if noise in name_lower.split():
            return False
    return True


def extract_purchaser(text: str) -> str:
    NAME_RE = r'([A-Z][a-z]{1,20}(?:[ \t]+[A-Z][a-z]{1,20}){1,2})'
    lines = [l.strip() for l in text.split('\n')]

    for i, line in enumerate(lines):
        if re.search(r'name\s+on\s+card[:\s]*', line, re.IGNORECASE):
            m = re.search(r'name\s+on\s+card[:\s]+' + NAME_RE, line, re.IGNORECASE)
            if m and _is_valid_person_name(m.group(1)):
                return m.group(1).strip()
            for j in range(i + 1, min(i + 4, len(lines))):
                nl = lines[j].strip()
                if nl:
                    nm = re.match(r'^' + NAME_RE + r'$', nl)
                    if nm and _is_valid_person_name(nm.group(1)):
                        return nm.group(1).strip()
                    break

    for i, line in enumerate(lines):
        if re.search(r'ordered\s+by[:\s]*', line, re.IGNORECASE):
            m = re.search(r'ordered\s+by[:\s]+' + NAME_RE, line, re.IGNORECASE)
            if m and _is_valid_person_name(m.group(1)):
                return m.group(1).strip()
            for j in range(i + 1, min(i + 4, len(lines))):
                nl = lines[j].strip()
                if nl:
                    nm = re.match(r'^' + NAME_RE + r'$', nl)
                    if nm and _is_valid_person_name(nm.group(1)):
                        return nm.group(1).strip()
                    break

    for i, line in enumerate(lines):
        m = re.search(r'attention[:\s]+([A-Z][A-Z\s]{2,40})', line, re.IGNORECASE)
        if m:
            raw = m.group(1).strip().title()
            if _is_valid_person_name(raw):
                return raw
        if re.fullmatch(r'attention[:\s]*', line, re.IGNORECASE):
            for j in range(i + 1, min(i + 4, len(lines))):
                nl = lines[j].strip()
                if nl:
                    candidate = nl.title()
                    if _is_valid_person_name(candidate):
                        return candidate
                    break

    personal_labels = [
        r'customer[:\s]+',
        r'member[:\s]+',
        r'purchaser[:\s]+',
        r'buyer[:\s]+',
        r'cardholder[:\s]+',
    ]
    for i, line in enumerate(lines):
        for ctx in personal_labels:
            m = re.search(ctx + NAME_RE, line, re.IGNORECASE)
            if m and _is_valid_person_name(m.group(1)):
                return m.group(1).strip()
            if re.fullmatch(ctx.rstrip(r'[:\\s]+') + r'[:\s]*', line, re.IGNORECASE):
                for j in range(i + 1, min(i + 4, len(lines))):
                    nl = lines[j].strip()
                    if nl:
                        nm = re.match(r'^' + NAME_RE + r'$', nl)
                        if nm and _is_valid_person_name(nm.group(1)):
                            return nm.group(1).strip()
                        break

    m = re.search(r'(?:Hello|Hi|Dear)[,\s]+' + NAME_RE + r'[,!]', text, re.IGNORECASE)
    if m and _is_valid_person_name(m.group(1)):
        return m.group(1).strip()

    for i, line in enumerate(lines):
        if re.fullmatch(r'ship\s+to[:\s]*', line, re.IGNORECASE):
            for j in range(i + 1, min(i + 5, len(lines))):
                nl = lines[j].strip()
                if nl:
                    nm = re.match(r'^' + NAME_RE + r'$', nl)
                    if nm and _is_valid_person_name(nm.group(1)):
                        return nm.group(1).strip()
                    break

    skip_phrases = {
        'Thank You', 'Order Number', 'Ship Date', 'Order Date',
        'Your Order', 'Free Returns', 'Estimated Delivery',
        'Order Type', 'Drive Thru', 'Ship To', 'Bill To',
        'Order Confirmation', 'Invoice Date', 'Ordered By',
        'United States', 'United Kingdom', 'Contact Name',
        'Ship Via',
    }
    for line in lines[:40]:
        m = re.match(r'^([A-Z][a-z]{1,20}(?:[ \t]+[A-Z][a-z]{1,20}){1,2})$', line)
        if m:
            name = m.group(1)
            if name not in skip_phrases and _is_valid_person_name(name):
                return name

    if LLM_READY:
        return _llm_extract_purchaser(text)

    return ""


def _llm_extract_purchaser(raw_text: str) -> str:
    trimmed = trim_receipt(raw_text, "", max_chars=600)
    try:
        response = ollama.chat(
            model="mistral",
            messages=[{"role": "user", "content": (
                f"[INST] Here is a receipt or invoice:\n\n"
                f"\"\"\"\n{trimmed}\n\"\"\"\n\n"
                f"What is the full name of the person who made this purchase? "
                f"Look for fields like 'Name on Card', 'Ordered By', 'Customer', 'Cardholder', 'Ship To', or a greeting. "
                f"Reply with only the person's full name, nothing else. "
                f"If you cannot find a person's name, reply with exactly: unknown [/INST]"
            )}],
            options={"temperature": 0.1, "stop": ["\n"]}
        )
        name = response["message"]["content"].strip().strip('.,')
        if name.lower() == "unknown" or not name:
            return ""
        if 3 < len(name) < 50 and '\n' not in name:
            return name
    except Exception:
        pass
    return ""


#CATEGORY EXTRACTION (LLM only)
def extract_category(text: str, vendor: str) -> str:
    if LLM_READY:
        return _llm_extract_category(text)
    return "Uncategorized"

def _llm_extract_category(raw_text: str) -> str:
    trimmed = trim_receipt(raw_text, "", max_chars=800)
    try:
        response = ollama.chat(
            model="mistral",
            messages=[{"role": "user", "content": (
                f"[INST] Here is a purchase receipt:\n\n"
                f"\"\"\"\n{trimmed}\n\"\"\"\n\n"
                f"What is the single best category word for this purchase? "
                f"Examples: Electronics, Hardware, Food, Clothing, Software, Medical, Tools, Office, Fasteners, Chemicals, Safety, Lumber, Plumbing, Automotive, Sporting, etc. "
                f"You can use any category word that fits — it does not have to be from the examples. "
                f"Reply with only one word, the category name. Nothing else. [/INST]"
            )}],
            options={"temperature": 0.1, "stop": ["\n", "."]}
        )
        category = response["message"]["content"].strip().strip('.,').title()
        if category and 2 < len(category) < 30 and '\n' not in category:
            return category
    except Exception:
        pass
    return "Uncategorized"

# ITEM EXTRACTION
def extract_item(raw_text: str, vendor: str) -> str:
    if not LLM_READY:
        return ""
    trimmed = trim_receipt(raw_text, vendor, max_chars=1000)
    try:
        response = ollama.chat(
            model="mistral",
            messages=[{"role": "user", "content": (
                f"[INST] Here is a purchase receipt:\n\n"
                f"\"\"\"\n{trimmed}\n\"\"\"\n\n"
                f"What is the primary item or items purchased? "
                f"Give a short, plain-English name like 'Stainless Steel Dowel Pins' or 'Laptop Charger' or 'Coffee and Pastry'. "
                f"No part numbers, no dimensions, no quantities, no company names, no prices. "
                f"If multiple distinct items, list them separated by commas, but keep it brief. "
                f"Reply with only the item name(s), nothing else. [/INST]"
            )}],
            options={"temperature": 0.1, "stop": ["\n"]}
        )
        item = response["message"]["content"].strip().strip('.,')
        if item and 2 < len(item) < 100 and '\n' not in item:
            return item
    except Exception:
        pass
    return ""

# RECEIPT TRIMMER
def trim_receipt(raw_text: str, vendor: str, max_chars: int = 1800) -> str:
    if len(raw_text) <= max_chars:
        return raw_text

    lines = [l.strip() for l in raw_text.split('\n') if l.strip()]

    important_keywords = [
        r'\$[\d,]+\.\d{2}',
        r'\d+\s*[xX]\s*\d',
        r'qty|quantity',
        r'item|product|description',
        r'part\s*#|sku|model',
        r'total|amount|due|paid',
    ]

    scored_lines = []
    for line in lines:
        score = 0
        for pattern in important_keywords:
            if re.search(pattern, line, re.IGNORECASE):
                score += 1
        scored_lines.append((score, line))

    scored_lines.sort(key=lambda x: x[0], reverse=True)

    kept = []
    total_chars = 0
    for score, line in scored_lines:
        if total_chars + len(line) <= max_chars:
            kept.append(line)
            total_chars += len(line)
        if total_chars >= max_chars:
            break

    return '\n'.join(kept)


# DETAILS SECTION
def generate_about_section(vendor: str, price: float, category: str = "", raw_text: str = "") -> str:
    trimmed_receipt = trim_receipt(raw_text, vendor, max_chars=1800)

    prompt = (
        f"[INST] "
        f"Here is the full text of a purchase receipt:\n\n"
        f"\"\"\"\n{trimmed_receipt}\n\"\"\"\n\n"
        f"Category: {category}\n"
        f"Total Price: ${price:.2f}\n\n"
        f"Background (do not mention this in your output): The buyer is a biomedical engineering company "
        f"that builds prosthetic bionic arms. Use this only to infer what the purchased items are used for.\n\n"
        f"Write EXACTLY 2 sentences. No more, no less.\n"
        f"Sentence 1 (past tense): Identify what the items are in plain human-readable form.\n"
        f"Sentence 2 (present tense): Explain specifically what these items are used for in mechanical or prosthetic assembly.\n\n"
        f"Hard rules:\n"
        f"- You MUST write exactly 2 complete sentences ending with a period\n"
        f"- Focus entirely on the purchased items, not the company or its mission\n"
        f"- Be specific about the application in sentence 2\n"
        f"- Never mention any company name, person, vendor, or organization\n"
        f"- Never mention prices, dates, order numbers, locations, or contact info\n"
        f"- NEVER USE HEDGING LANGUAGE — speak with 100% certainty\n"
        f"- Never use: 'likely', 'probably', 'appears', 'seems', 'may', 'might', "
        f"'could', 'potentially', 'utilized', 'undisclosed', 'unknown', 'unspecified'\n"
        f"- No personal pronouns: 'I', 'my', 'we', 'our', 'they', 'their'\n"
        f"- No part numbers, product codes, dimensions, or pack counts\n"
        f"- Do not label sentences with 'Sentence 1' or 'Sentence 2'\n"
        f"- No lists — just two plain prose sentences\n"
        f"- Correct grammar, no run-on sentences\n"
        f"- Output only the 2 sentences and absolutely nothing else\n"
        f"[/INST]"
    )

    response = ollama.chat(
        model="mistral",
        messages=[{"role": "user", "content": prompt}],
        options={
            "temperature": 0.3,
            "repeat_penalty": 1.3,
            "stop": ["\n\n", "[INST]"]
        }
    )

    full_text = response["message"]["content"].strip()

    sentences = re.split(r'(?<=[.!?])\s+', full_text.strip())
    sentences = [s.strip() for s in sentences if s.strip()]
    if len(sentences) >= 2:
        return sentences[0].rstrip('.') + '. ' + sentences[1].rstrip('.') + '.'
    elif len(sentences) == 1:
        return sentences[0].rstrip('.') + '.'

    return full_text


# PARSE ENDPOINT
@app.post("/parse")
async def parse_file(file: UploadFile = File(...)):
    filename   = file.filename.lower()
    file_bytes = await file.read()
    raw_text   = extract_text_from_file(file_bytes, filename)

    vendor = extract_vendor(raw_text)
    price_str = extract_price(raw_text)
    date = extract_date(raw_text)
    category = extract_category(raw_text, vendor)
    purchaser = extract_purchaser(raw_text)

    loop = asyncio.get_event_loop()

    if LLM_READY:
        item_task = loop.run_in_executor(
            _executor,
            extract_item,
            raw_text, vendor
        )
        details_task = loop.run_in_executor(
            _executor,
            generate_about_section,
            vendor, float(price_str or 0), category, raw_text
        )
        item, details = await asyncio.gather(item_task, details_task)
    else:
        item    = ""
        details = ""

    return {
        "vendor":    vendor,
        "amount":    price_str if price_str else None,
        "date":      date,
        "category":  category,
        "purchaser": purchaser,
        "item":      item,
        "details":   details,
        "about":     details,
    }