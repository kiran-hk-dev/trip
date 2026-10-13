-- =====================================================================
-- TripSplit World — 0005 reference data seed
--
-- IMPORTANT — read before editing this file.
--
-- Every row here carries source_url + source_org + verification state. This
-- seed is deliberately loaded as `verification = 'unverified'` or
-- `'needs_review'`, because nothing in this repository can prove that a phone
-- number was correct at the moment the app shipped. TripSplit's UI must show
-- these states and must always offer a "open the official source" action.
--
-- Do NOT add a number you cannot trace to an official publisher. Do not
-- crowd-source. If a row cannot be verified, either leave it unverified or do
-- not insert it — never invent a replacement.
--
-- To promote a row to 'verified', run the Edge Function `sync-resources`
-- (or a reviewed manual UPDATE) and record the check in
-- source_verification_log.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Emergency services — Hong Kong SAR
-- Sources: Hong Kong Police Force, Fire Services Department, Immigration Dept.
-- ---------------------------------------------------------------------
insert into public.emergency_resources
  (country_code, country_name, category, service_name, phone, address, official_url,
   languages, hours, availability_note, source_url, source_org, verification,
   last_verified_at, review_due_at)
values
  ('HK', 'Hong Kong SAR', 'police', 'Police (999 — emergency)', '999', null,
   'https://www.police.gov.hk/en/contact/index.html',
   array['English','中文','繁體'], '24 hours',
   '999 is the single emergency line for police, fire and ambulance in Hong Kong. 112 also routes to emergency services.',
   'https://www.police.gov.hk/en/contact/index.html',
   'Hong Kong Police Force', 'unverified', null, now() + interval '90 days'),

  ('HK', 'Hong Kong SAR', 'police', 'Police non-emergency / lost property', '2527 2222', null,
   'https://www.police.gov.hk/en/contact/index.html',
   array['English','中文','繁體'], '24 hours',
   'Non-emergency line for reporting crime that is not in progress.',
   'https://www.police.gov.hk/en/contact/index.html',
   'Hong Kong Police Force', 'unverified', null, now() + interval '90 days'),

  ('HK', 'Hong Kong SAR', 'ambulance', 'Ambulance (999 — emergency)', '999', null,
   'https://www.hkfsd.gov.hk/english/contactus/contactus.html',
   array['English','中文','繁體'], '24 hours',
   'Emergency medical services via 999.',
   'https://www.hkfsd.gov.hk/english/contactus/contactus.html',
   'Hong Kong Fire Services Department', 'unverified', null, now() + interval '90 days'),

  ('HK', 'Hong Kong SAR', 'fire', 'Fire services (999 — emergency)', '999', null,
   'https://www.hkfsd.gov.hk/english/contactus/contactus.html',
   array['English','中文','繁體'], '24 hours',
   'Emergency fire and rescue via 999.',
   'https://www.hkfsd.gov.hk/english/contactus/contactus.html',
   'Hong Kong Fire Services Department', 'unverified', null, now() + interval '90 days'),

  ('HK', 'Hong Kong SAR', 'immigration', 'Immigration Department enquiries', '2824 6111', null,
   'https://www.immd.gov.hk/eng/services/contact.html',
   array['English','中文','繁體'], '24 hours for the general enquiries line',
   'General enquiries line published by the Immigration Department.',
   'https://www.immd.gov.hk/eng/services/contact.html',
   'Hong Kong Immigration Department', 'unverified', null, now() + interval '90 days'),

  ('HK', 'Hong Kong SAR', 'tourist_assistance', 'Tourist Assistance Unit (Police)', '2527 2222', null,
   'https://www.police.gov.hk/en/contact/index.html',
   array['English','中文','繁體'], '24 hours',
   'Police unit assisting visitors; confirm current operating hours with the police before relying on it.',
   'https://www.police.gov.hk/en/contact/index.html',
   'Hong Kong Police Force', 'unverified', null, now() + interval '90 days'),

  ('HK', 'Hong Kong SAR', 'consular_directory', 'Consular contacts directory', null, null,
   'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit/consular-contacts.html',
   array['English','中文','繁體'], null,
   'Official directory of foreign consulates in the Hong Kong SAR. Not every country maintains a resident mission here; some are accredited from another city.',
   'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit/consular-contacts.html',
   'Hong Kong Immigration Department', 'unverified', null, now() + interval '180 days'),

  ('HK', 'Hong Kong SAR', 'lost_property', 'Police lost property office', null, null,
   'https://www.police.gov.hk/en/contact/index.html',
   array['English','中文','繁體'], null,
   'Confirm the current office address and opening hours directly with the police before travelling there.',
   'https://www.police.gov.hk/en/contact/index.html',
   'Hong Kong Police Force', 'unverified', null, now() + interval '90 days'),

  -- A representative global baseline. Emergency numbers vary by jurisdiction;
  -- the app must never present one global number as valid everywhere.
  ('GB', 'United Kingdom', 'emergency', 'Police, ambulance and fire', '999', null,
   'https://www.gov.uk/guidance/999-and-112-the-uks-national-emergency-numbers',
   array['English'], '24 hours',
   '112 also works and connects to the same emergency services.',
   'https://www.gov.uk/guidance/999-and-112-the-uks-national-emergency-numbers',
   'UK Government (GOV.UK)', 'unverified', null, now() + interval '90 days'),

  ('US', 'United States', 'police', 'Police, ambulance and fire', '911', null,
   'https://www.911.gov/',
   array['English','Español'], '24 hours',
   'Nationwide emergency number; state and local coverage varies.',
   'https://www.911.gov/',
   'National Emergency Number System', 'unverified', null, now() + interval '90 days'),

  ('IN', 'India', 'emergency', 'Police, ambulance, fire and disaster', '112', null,
   'https://www.indiacode.nic.in/',
   array['English','हिन्दी'], '24 hours',
   '112 is the national integrated emergency number. Coverage varies by state.',
   'https://www.indiacode.nic.in/',
   'Government of India', 'unverified', null, now() + interval '90 days'),

  ('JP', 'Japan', 'police', 'Police (110)', '110', null,
   'https://www.npa.go.jp/english/bureau/traffic/index.html',
   array['日本語','English'], '24 hours',
   'Fire and ambulance in Japan is 119.',
   'https://www.npa.go.jp/english/',
   'National Police Agency of Japan', 'unverified', null, now() + interval '90 days'),

  ('JP', 'Japan', 'ambulance', 'Fire and ambulance (119)', '119', null,
   'https://www.fdma.go.jp/mission/prepare/119/english/index.html',
   array['日本語','English'], '24 hours',
   'Japan uses 119 for fire and ambulance rather than a combined 112 line.',
   'https://www.fdma.go.jp/mission/prepare/119/english/index.html',
   'Japan Fire and Disaster Management Agency', 'unverified', null, now() + interval '90 days'),

  ('SG', 'Singapore', 'police', 'Police (999)', '999', null,
   'https://www.police.gov.sg/Contact-Us',
   array['English','中文',' Bahasa Melayu','தமிழ்'], '24 hours',
   'Ambulance and fire services in Singapore use 995.',
   'https://www.police.gov.sg/Contact-Us',
   'Singapore Police Force', 'unverified', null, now() + interval '90 days'),

  ('AU', 'Australia', 'police', 'Police, ambulance and fire (000)', '000', null,
   'https://www.triplezero.gov.au/',
   array['English'], '24 hours',
   '112 also works from mobile phones in Australia.',
   'https://www.triplezero.gov.au/',
   'Australian Government — Triple Zero', 'unverified', null, now() + interval '90 days'),

  ('DE', 'Germany', 'police', 'Police (110)', '110', null,
   'https://www.bundespolizei.de/EN/Websites/contact/contact-node.html',
   array['Deutsch','English'], '24 hours',
   'Emergency medical and fire services in Germany use 112.',
   'https://www.bundespolizei.de/EN/Websites/contact/contact-node.html',
   'Federal Criminal Police Office (BKA)', 'unverified', null, now() + interval '90 days')
on conflict (country_code, category, service_name) do update
  set phone            = excluded.phone,
      address          = excluded.address,
      official_url     = excluded.official_url,
      hours            = excluded.hours,
      availability_note= excluded.availability_note,
      source_url       = excluded.source_url,
      source_org       = excluded.source_org,
      updated_at       = now();

-- ---------------------------------------------------------------------
-- Emergency guides. Content is generic, procedurally correct guidance that
-- applies wherever you are; specific contacts are looked up at runtime from
-- emergency_resources so a stale number can be corrected without rewriting
-- the guide.
-- ---------------------------------------------------------------------
insert into public.emergency_guides
  (slug, country_code, title, summary, steps, languages, phrases,
   source_url, source_org, verification, review_due_at)
values
  ('lost-passport-abroad', null, 'Lost or stolen passport abroad',
   'A step-by-step plan that works in any country: get safe, report to the police, contact your embassy or consulate, prepare replacement documents, and sort out your travel home.',
   $json$[
     {"heading":"1. Get to safety first","body":"Move to a well-lit, staffed place such as a hotel lobby, a café, a shop, a hospital waiting area or a police station. If you are in immediate danger, call the local emergency number now. Do not confront or chase anyone you suspect of taking your belongings.","actions":[],"callouts":["Your safety comes before your belongings. Police reports are useful but they do not replace a travel document."]},
     {"heading":"2. Report to the police","body":"Go to a police station or ask authorised staff — hotel reception, an airport or station police desk, a tour operator's desk — to help you reach the police. Report the loss or theft and ask for an incident reference number in writing; you will usually need it for the embassy.","actions":[{"label":"Find a police station near you","url":"https://www.openstreetmap.org/search?query=police%20station","kind":"map"}],"callouts":["If your phone is also gone, ask the station for a copy or the reference number before you leave.","A police report does not replace a passport. It supports your replacement application."]},
     {"heading":"3. Contact your embassy or consulate","body":"Contact the embassy or consulate of the country whose passport you hold — not the country you normally live in. Some countries have no embassy in your current location and use an honorary consulate or an accredited mission from a neighbouring country. Your home country's foreign ministry directory will tell you which arrangement applies.","actions":[{"label":"Find your country's embassy or consulate","url":"https://www.consularhelp.dfa.gov.au/","kind":"external"}],"callouts":["Ask specifically about an emergency travel document, a temporary passport or a replacement passport. The options available differ by nationality and by jurisdiction — the consular office decides what it can issue.","Some embassies only issue emergency documents for nationals who are stranded. A valid onward ticket and proof of residence are commonly required."]},
     {"heading":"4. Put replacement documents together","body":"Collect what you can and keep digital copies. The exact list is set by your embassy, so confirm it with them rather than assuming.","actions":[],"callouts":["Police report or incident reference number, if you have one","Any copy or photo of the passport, or the passport number, if available","An alternative identity document, for example a driving licence or national identity card","Passport photographs, if the embassy requests them and you do not have a photo booth nearby","Proof of citizenship or nationality, if requested","Flight itinerary or booking reference","Accommodation details","Completed application forms and the applicable fee","Proof that you have paid any outstanding fee or that you are leaving the country"]},
     {"heading":"5. Contact your airline","body":"Call the airline before you go to the airport. Explain what has happened and ask what they will accept. Airlines may require a specific document type before they will let you board.","actions":[],"callouts":["No airline can promise boarding without a valid travel document. An airline decides whether a specific document is acceptable for boarding on a specific route.","Check every transit country as well as the destination — your return can fail on transit rules rather than at the final destination.","Ask whether the existing ticket can be reissued rather than repurchased."]},
     {"heading":"6. Get home safely","body":"Ask your consular service what travel document you need and what the exit requirements are for your nationality. Then rebook flights, arrange temporary accommodation and keep every receipt.","actions":[],"callouts":["Confirm entry requirements for your destination country and for any transit countries.","Ask whether an exit permit, visa replacement or additional local procedure applies.","Keep copies of every police report and every message from the embassy.","If you need emergency funds, your embassy or insurer may be able to advise on documented emergency assistance."]}
   ]$json$,
   '{"en":true,"zh-Hant":false,"es":false,"fr":false,"de":false,"ja":false,"ar":false,"hi":false}',
   $json${
     "en":[
       "Excuse me, I need help. My passport has been lost or stolen.",
       "I need a police report. Could I have an incident reference number, please?",
       "Which embassy or consulate can help me?",
       "I need an emergency travel document to get home.",
       "Could I have a receipt, please? This is for my insurance claim."
     ],
     "zh-Hant":[
       "不好意思，我需要幫助。我的護照遺失或被盜了。",
       "我需要報警。請問可以給我一張報案編號嗎？",
       "哪個使領館可以幫助我？",
       "我需要旅行證件回家。"
     ],
     "es":["Disculpe, necesito ayuda. He perdido o me han robado el pasaporte.","Necesito poner una denuncia. ¿Pueden darme un número de referencia, por favor?"],
     "fr":["Excusez-moi, j'ai besoin d'aide. Mon passeport a été perdu ou volé.","J'ai besoin de faire un signalement. Puis-je avoir un numéro de référence, s'il vous plaît ?"],
     "de":["Entschuldigen Sie, ich brauche Hilfe. Mein Pass ist verloren oder gestohlen.","Ich brauche eine Polizeianzeige. Könnten Sie mir bitte eine Referenznummer geben?"],
     "ja":["すみません、助けてください。パスポートをなくしました。","警察に届け出たいのですが、受理番号をいただけますか。"]
   }$json$,
   'https://www.gov.uk/foreign-travel-advice',
   'Official government foreign travel advice portals',
   'unverified', now() + interval '180 days')
on conflict (slug) do update
  set steps = excluded.steps,
      phrases = excluded.phrases,
      languages = excluded.languages;

-- Hong Kong-specific: same procedure, Hong Kong contacts and Traditional
-- Chinese phrasing. Contacts are resolved from emergency_resources at runtime.
insert into public.emergency_guides
  (slug, country_code, title, summary, steps, languages, phrases,
   source_url, source_org, verification, review_due_at)
values
  ('lost-passport-hong-kong', 'HK', 'Lost or stolen passport in Hong Kong',
   'The standard lost-passport procedure, with the Hong Kong SAR emergency contacts and Traditional Chinese phrasing. Confirm every number on the official Hong Kong Police or Immigration page before you rely on it.',
   $json$[
     {"heading":"1. Are you in immediate danger?","body":"If you are being followed, threatened or hurt right now, call 999. In Hong Kong, 999 reaches police, fire services and ambulance. 112 also connects to the same emergency services.","actions":[{"label":"Call 999","url":"tel:999","kind":"call"}],"callouts":["Move to a staffed, well-lit place such as a hotel lobby, a shopping centre, a hospital or a police station. Do not confront anyone you suspect."]},
     {"heading":"2. Report the loss or theft to the police","body":"Ask your hotel, the MTR staff, a shop or a police station to help you reach the police. Report the loss and request an incident reference number — you will need it for the Immigration Department and your consulate.","actions":[{"label":"Find a Hong Kong police station on the map","url":"https://www.openstreetmap.org/search?query=police%20station%20Hong%20Kong","kind":"map"},{"label":"Hong Kong Police contact page","url":"https://www.police.gov.hk/en/contact/index.html","kind":"external"}],"callouts":["999 is for emergencies. For a loss or theft that is not in progress, use the published non-emergency line.","A police report does not replace a travel document."]},
     {"heading":"3. Reach the right embassy or consulate in Hong Kong","body":"Find the mission that covers your nationality. Not every country maintains a resident consulate in the Hong Kong SAR — some are represented by an honorary consulate or a mission accredited from another city. The Hong Kong Immigration Department publishes a consular contacts directory.","actions":[{"label":"Hong Kong Immigration consular contacts directory","url":"https://www.immd.gov.hk/eng/services/visas/visas-entry-permit/consular-contacts.html","kind":"external"}],"callouts":["Bring your national passport reference and proof of identity.","Ask about an emergency travel document or a replacement passport. Availability and procedure are decided by your own government, not by Hong Kong.","If your mission is not in Hong Kong, they will tell you which office to contact instead."]},
     {"heading":"4. Prepare what the embassy asks for","body":"Confirm the exact list with your own consular service before you go anywhere.","actions":[],"callouts":["Police report or incident reference number","An alternative identity document","Passport copy or passport number if you have it","Passport photographs if requested","Proof of citizenship or nationality if requested","Flight itinerary or booking reference","Accommodation details","Completed forms and the fee"]},
     {"heading":"5. Contact your airline before going to the airport","body":"Call the airline and explain the situation. Confirm what document they will accept for your specific route.","actions":[],"callouts":["An airline cannot promise boarding without an acceptable travel document.","Check transit-country rules as well as your destination — Hong Kong may be your transit point rather than your destination."]},
     {"heading":"6. Leaving Hong Kong and getting home","body":"Confirm with your consular service what you need for the exit and for boarding home.","actions":[],"callouts":["Keep every receipt and every copy of your police report.","If you need emergency funds, ask your consular service or your insurer what documented assistance is available.","Local rules and procedures can change — confirm with official sources rather than with travel forums."]}
   ]$json$,
   '{"en":true,"zh-Hant":true,"zh-Hans":false,"pt":false,"ko":false,"ja":false}',
   $json${
     "en":[
       "Excuse me, I need help. My passport has been lost or stolen.",
       "I need to report a lost passport. Could I have an incident reference number, please?",
       "Which embassy or consulate can assist me?",
       "I need an emergency travel document.",
       "Please call an ambulance." ,
       "Please call the police."
     ],
     "zh-Hant":[
       "你好，我需要幫助。我的護照遺失了。",
       "你好，我需要幫助。我的護照被盜了。",
       "我要報警遺失護照，可以給我一個報案編號嗎？",
       "哪一個使領館可以幫助我？",
       "我需要旅行證件或臨時護照回家。",
       "請幫我叫救護車。",
       "請幫我叫警察。"
     ],
     "pt":["Desculpe, preciso de ajuda. Perdi ou roubaram o meu passaporte.","Preciso de fazer um relatório. Podem dar-me um número de referência, por favor?"]
   }$json$,
   'https://www.police.gov.hk/en/contact/index.html',
   'Hong Kong Police Force / Immigration Department',
   'unverified', now() + interval '60 days')
on conflict (slug) do update
  set steps = excluded.steps,
      phrases = excluded.phrases,
      languages = excluded.languages;

-- ---------------------------------------------------------------------
-- Visa / entry resource directories. These are *links to official pages*,
-- not visa rules. The app never states a requirement on the user's behalf.
-- ---------------------------------------------------------------------
insert into public.visa_resource_links
  (country_code, country_name, official_url, source_org, source_url, category, verification, review_due_at)
values
  ('HK', 'Hong Kong SAR', 'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit.html',
   'Hong Kong Immigration Department',
   'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit.html',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('JP', 'Japan', 'https://www.mofa.go.jp/visa/index.html',
   'Ministry of Foreign Affairs of Japan',
   'https://www.mofa.go.jp/visa/index.html',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('SG', 'Singapore', 'https://www.ica.gov.sg/enter-transit-go',
   'Immigration & Checkpoints Authority of Singapore',
   'https://www.ica.gov.sg/enter-transit-go',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('AE', 'United Arab Emirates', 'https://www.dubaivisae-services.ae/',
   'General Directorate of Residency and Foreigners Affairs',
   'https://www.dubaivisae-services.ae/',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('TH', 'Thailand', 'https://www.thaievisa.go.th/',
   'Thai e-Visa Service',
   'https://www.thaievisa.go.th/',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('IN', 'India', 'https://indianvisaonline.gov.in/',
   'Government of India, Ministry of External Affairs',
   'https://indianvisaonline.gov.in/',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('US', 'United States', 'https://travel.state.gov/content/travel/en/us-visas.html',
   'U.S. Department of State',
   'https://travel.state.gov/content/travel/en/us-visas.html',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('GB', 'United Kingdom', 'https://www.gov.uk/check-uk-visa',
   'UK Home Office',
   'https://www.gov.uk/check-uk-visa',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('AU', 'Australia', 'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing',
   'Australian Department of Home Affairs',
   'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing',
   'entry_requirements', 'unverified', now() + interval '90 days'),
  ('MY', 'Malaysia', 'https://www.imi.gov.my/index.php/en/main-services/visa/visa-requirement-by-country/',
   'Immigration Department of Malaysia',
   'https://www.imi.gov.my/',
   'entry_requirements', 'unverified', now() + interval '90 days')
on conflict (country_code, category, official_url) do update
  set official_url = excluded.official_url,
      source_org = excluded.source_org,
      source_url = excluded.source_url;

-- ---------------------------------------------------------------------
-- Travel advisories — pointers to the official advisory publisher.
-- ---------------------------------------------------------------------
insert into public.travel_advisories
  (country_code, country_name, official_url, source_org, source_url, verification, review_due_at)
values
  ('HK', 'Hong Kong SAR', 'https://www.travel.gov.hk/en/',
   'Travel Industry and Services Bureau, HKSAR Government',
   'https://www.travel.gov.hk/en/', 'unverified', now() + interval '30 days'),
  ('GB', 'United Kingdom', 'https://www.gov.uk/foreign-travel-advice',
   'UK Foreign, Commonwealth & Development Office',
   'https://www.gov.uk/foreign-travel-advice', 'unverified', now() + interval '30 days'),
  ('US', 'United States', 'https://travel.state.gov/content/travel/en/traveladvisories/traveladvisories.html/',
   'U.S. Department of State',
   'https://travel.state.gov/content/travel/en/traveladvisories/traveladvisories.html/',
   'unverified', now() + interval '30 days'),
  ('IN', 'India', 'https://travelmehs.microsoft.com/en-IN/',
   'Ministry of External Affairs, Government of India',
   'https://mea.gov.in/', 'unverified', now() + interval '30 days'),
  ('AU', 'Australia', 'https://www.smartraveller.gov.au/destinations',
   'Australian Department of Foreign Affairs and Trade',
   'https://www.smartraveller.gov.au/', 'unverified', now() + interval '30 days')
on conflict (country_code, source_org) do update
  set official_url = excluded.official_url,
      source_url = excluded.source_url;

-- ---------------------------------------------------------------------
-- Destination catalogue (clearly fictional-free: real places, but the cost
-- figures are editable estimates, flagged as such in the UI).
-- ---------------------------------------------------------------------
insert into public.destinations
  (name, country, country_code, city, latitude, longitude, timezone,
   currency, languages, image_url, summary, categories,
   typical_daily_budget_minor, is_demo, verified)
values
  ('Hong Kong', 'Hong Kong SAR', 'HK', 'Hong Kong', 22.3193, 114.1694, 'Asia/Hong_Kong',
   'HKD', array['Cantonese','English','Mandarin'],
   'https://images.unsplash.com/photo-1536599018102-9f803c140fc1?auto=format&fit=crop&w=1200&q=70',
   'A dense harbour city of skyscrapers, street food and hiking trails minutes from the skyline. The MTR reaches almost everywhere, and Octopus cards work on transport and in many shops.',
   array['city','food','shopping','family','sightseeing'],
   65000, false, false),

  ('Kyoto', 'Japan', 'JP', 'Kyoto', 35.0116, 135.7681, 'Asia/Tokyo',
   'JPY', array['Japanese','English'],
   'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=1200&q=70',
   'Temples, geisha districts and seasonal gardens. Spring blossom and autumn maple draw the largest crowds; early winter is quietest.',
   array['heritage','culture','nature','food','relaxation'],
   18000, false, false),

  ('Singapore', 'Singapore', 'SG', 'Singapore', 1.3521, 103.8198, 'Asia/Singapore',
   'SGD', array['English','Mandarin','Malay','Tamil'],
   'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?auto=format&fit=crop&w=1200&q=70',
   'A city-state that is unusually easy to navigate: fast trains, hawker centres, and strict rules with clear published guidance.',
   array['city','food','family','shopping','sightseeing'],
   90000, false, false),

  ('Goa', 'India', 'IN', 'Goa', 15.2993, 74.1240, 'Asia/Kolkata',
   'INR', array['Konkani','Hindi','English'],
   'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=1200&q=70',
   'A long coastline with beach shacks, Portuguese-era churches and monsoon-season green. North Goa is busier; south Goa is quieter.',
   array['beaches','relaxation','food','adventure'],
   35000, false, false),

  ('Queenstown', 'New Zealand', 'NZ', 'Queenstown', -45.0312, 168.6626, 'Pacific/Auckland',
   'NZD', array['English','Te Reo Māori'],
   'https://images.unsplash.com/photo-1469521669194-babb45599def?auto=format&fit=crop&w=1200&q=70',
   'Alpine lakes and adventure sports capital of the Southern Hemisphere. Milford Sound and the Routeburn track are the signature day trips.',
   array['adventure','nature','mountains','relaxation'],
   15000, false, false),

  ('Lisbon', 'Portugal', 'PT', 'Lisbon', 38.7223, -9.1393, 'Europe/Lisbon',
   'EUR', array['Portuguese','English'],
   'https://images.unsplash.com/photo-1555881400-74d7acaacd8b?auto=format&fit=crop&w=1200&q=70',
   'Hills, tiled facades and a waterfront that fills with music at night. Tram 28 is famous and extremely crowded; the metro is calmer.',
   array['city','heritage','food','beaches'],
   75000, false, false),

  ('Bangkok', 'Thailand', 'TH', 'Bangkok', 13.7563, 100.5018, 'Asia/Bangkok',
   'THB', array['Thai','English'],
   'https://images.unsplash.com/photo-1508009603885-50cf7c579365?auto=format&fit=crop&w=1200&q=70',
   'Temples, canals and a street-food culture that runs late. Combine with the Chao Phraya river and rail links to the old provincial cities.',
   array['city','food','culture','shopping','nightlife'],
   45000, false, false),

  ('Reykjavik', 'Iceland', 'IS', 'Reykjavik', 64.1466, -21.9426, 'Atlantic/Reykjavik',
   'ISK', array['Icelandic','English'],
   'https://images.unsplash.com/photo-1504893524553-b855bce32c67?auto=format&fit=crop&w=1200&q=70',
   'The most southerly point of the Greenland ridge. Geothermal pools, waterfalls and a long daylight season in summer.',
   array['nature','adventure','mountains','relaxation'],
   22000, false, false)
on conflict (name, country_code) do update
  set image_url = excluded.image_url,
      summary = excluded.summary,
      typical_daily_budget_minor = excluded.typical_daily_budget_minor;

-- ---------------------------------------------------------------------
-- Packing / pre-departure checklist templates.
--
-- Templates are stored as rows with a NULL trip_id owned by the demo/system
-- account is deliberately avoided: instead the templates live in a dedicated
-- `checklist_templates` table that every authenticated user may read, and
-- `copy_template_list` clones one into a per-user or per-trip list.
-- ---------------------------------------------------------------------
create table if not exists public.checklist_templates (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  kind        public.checklist_kind not null default 'packing',
  description text,
  items       jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now()
);

alter table public.checklist_templates enable row level security;
create policy "checklist_templates: public read"
  on public.checklist_templates for select using (true);

insert into public.checklist_templates (slug, name, kind, description, items)
values
  ('international-travel', 'International travel', 'predeparture',
   'General pre-departure checks for travelling internationally. These are reminders, not entry requirements — confirm rules for your nationality, residence, transit route and purpose with official sources.',
   '[
     {"label":"Valid passport","category":"documents"},
     {"label":"Passport validity checked against destination entry rules","category":"documents"},
     {"label":"Blank passport pages available","category":"documents"},
     {"label":"Visa or eTravel authorisation checked","category":"documents"},
     {"label":"Visa approved, where one is required","category":"documents"},
     {"label":"Flight tickets booked","category":"documents"},
     {"label":"Return or onward travel arranged","category":"documents"},
     {"label":"Accommodation confirmations saved","category":"documents"},
     {"label":"Travel insurance purchased, policy number saved","category":"insurance"},
     {"label":"Emergency contacts written down for offline use","category":"documents"},
     {"label":"Secure digital copy of passport and visa","category":"documents"},
     {"label":"Health or vaccination documents checked against official guidance","category":"health"},
     {"label":"Prescription medicines and supporting documentation packed","category":"health"},
     {"label":"Driving permit checked, if driving abroad","category":"transport"},
     {"label":"Two payment methods prepared","category":"money"},
     {"label":"Local SIM or roaming arranged","category":"connectivity"},
     {"label":"Power adapter for the destination","category":"electronics"},
     {"label":"Airport transfer booked","category":"transport"},
     {"label":"Key reservations downloaded for offline access","category":"documents"}
   ]'::jsonb),

  ('beach-holiday', 'Beach holiday', 'packing',
   'Warm-weather essentials.',
   '[
     {"label":"Swimwear","category":"clothing"},
     {"label":"Light clothing","category":"clothing"},
     {"label":"Sun hat and sunglasses","category":"accessories"},
     {"label":"Reef-safe sunscreen","category":"toiletries"},
     {"label":"Flip-flops","category":"clothing"},
     {"label":"Quick-dry towel","category":"accessories"},
     {"label":"Waterproof phone pouch","category":"accessories"},
     {"label":"Insect repellent","category":"health"},
     {"label":"After-sun lotion","category":"toiletries"},
     {"label":"Power bank","category":"electronics"}
   ]'::jsonb),

  ('cold-weather', 'Cold-weather destination', 'packing',
   'Layering for low temperatures.',
   '[
     {"label":"Thermal base layers","category":"clothing"},
     {"label":"Insulated jacket","category":"clothing"},
     {"label":"Waterproof and windproof outer shell","category":"clothing"},
     {"label":"Warm hat and gloves","category":"accessories"},
     {"label":"Wool socks","category":"clothing"},
     {"label":"Waterproof boots","category":"clothing"},
     {"label":"Lip balm with SPF","category":"toiletries"},
     {"label":"Hand warmers","category":"accessories"},
     {"label":"Head torch with spare batteries","category":"electronics"},
     {"label":"Camera spare batteries","category":"electronics"}
   ]'::jsonb),

  ('business-trip', 'Business trip', 'predeparture',
   'Short professional trip.',
   '[
     {"label":"Laptop and charger","category":"electronics"},
     {"label":"Presentation materials saved offline","category":"documents"},
     {"label":"Business cards","category":"documents"},
     {"label":"Formal outfit","category":"clothing"},
     {"label":"Travel insurance for business cover","category":"insurance"},
     {"label":"Meeting locations and addresses saved","category":"documents"},
     {"label":"Local currency or card ready","category":"money"},
     {"label":"Outfit for client meeting","category":"clothing"}
   ]'::jsonb),

  ('family-travel', 'Family travel', 'packing',
   'Travelling with children.',
   '[
     {"label":"Passport or birth certificate for each child","category":"documents"},
     {"label":"Child car seat if required","category":"transport"},
     {"label":"Favourite snacks and milk","category":"food"},
     {"label":"Reusable water bottles","category":"accessories"},
     {"label":"Small first-aid kit","category":"health"},
     {"label":"Entertainment for the journey","category":"electronics"},
     {"label":"Nappies and wipes","category":"toiletries"},
     {"label":"Comfort objects for bedtime","category":"accessories"}
   ]'::jsonb),

  ('adventure-trip', 'Adventure trip', 'packing',
   'Hiking, climbing or water sports.',
   '[
     {"label":"Broken-in hiking boots","category":"clothing"},
     {"label":"Rain shell","category":"clothing"},
     {"label":"Head torch with spare batteries","category":"electronics"},
     {"label":"Blister plasters and tape","category":"health"},
     {"label":"Water purification method","category":"health"},
     {"label":"High-energy snacks","category":"food"},
     {"label":"Insect repellent","category":"health"},
     {"label":"Emergency bivvy or poncho","category":"accessories"},
     {"label":"Offline map of the route","category":"navigation"},
     {"label":"First-aid kit","category":"health"}
   ]'::jsonb),

  ('long-stay', 'Long stay (over one month)', 'packing',
   'Extended-stay packing.',
   '[
     {"label":"Prescription cover for the full stay","category":"health"},
     {"label":"Laundry detergent","category":"toiletries"},
     {"label":"Extra clothing for the full duration","category":"clothing"},
     {"label":"Home SIM paused or forwarded","category":"connectivity"},
     {"label":"Storage or accommodation for excess luggage","category":"transport"},
     {"label":"Vaccination records","category":"health"},
     {"label":"Voltage and plug check for all accommodation","category":"electronics"}
   ]'::jsonb),

  ('domestic-travel', 'Domestic travel', 'predeparture',
   'Shorter trip within your own country.',
   '[
     {"label":"Photo ID for transport and hotels","category":"documents"},
     {"label":"Tickets booked","category":"documents"},
     {"label":"Accommodation confirmation","category":"documents"},
     {"label":"Phone charged and power bank packed","category":"electronics"},
     {"label":"Water and snacks for the journey","category":"food"},
     {"label":"Offline map of the destination","category":"navigation"}
   ]'::jsonb)
on conflict (slug) do update
  set items = excluded.items,
      description = excluded.description;

-- Clone a template into a real list the user owns.
create or replace function public.copy_template_list(
  p_template_slug text,
  p_name text default null,
  p_trip_id uuid default null,
  p_shared boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_template public.checklist_templates;
  v_list_id  uuid;
  v_item     jsonb;
  v_pos      int := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_trip_id is not null and not public.is_trip_member(p_trip_id) then
    raise exception 'Not a member of this trip' using errcode = '42501';
  end if;

  select * into v_template from public.checklist_templates where slug = p_template_slug;
  if not found then
    raise exception 'Unknown checklist template' using errcode = 'P0002';
  end if;

  insert into public.packing_lists (trip_id, owner_id, name, kind, is_shared, is_template)
  values (p_trip_id, auth.uid(), coalesce(p_name, v_template.name), v_template.kind, p_shared, true)
  returning id into v_list_id;

  for v_item in select * from jsonb_array_elements(v_template.items)
  loop
    insert into public.packing_list_items (list_id, label, category, position, available_offline)
    values (v_list_id, v_item ->> 'label', coalesce(v_item ->> 'category', 'other'), v_pos, true);
    v_pos := v_pos + 1;
  end loop;

  return v_list_id;
end;
$$;

