import 'package:flutter/material.dart';

import '../../data/models/reference.dart';

/// Maps each emergency scenario to the guide that handles it.
const List<({EmergencyCategory category, String guideSlug, IconData icon})>
kEmergencyScenarios =
    <({EmergencyCategory category, String guideSlug, IconData icon})>[
      (
        category: EmergencyCategory.lostPassport,
        guideSlug: 'lost-passport-abroad',
        icon: Icons.no_accounts_outlined,
      ),
      (
        category: EmergencyCategory.stolenWallet,
        guideSlug: 'lost-wallet',
        icon: Icons.account_balance_wallet_outlined,
      ),
      (
        category: EmergencyCategory.lostPhone,
        guideSlug: 'lost-phone',
        icon: Icons.smartphone_outlined,
      ),
      (
        category: EmergencyCategory.medical,
        guideSlug: 'medical-emergency',
        icon: Icons.medical_services_outlined,
      ),
      (
        category: EmergencyCategory.theft,
        guideSlug: 'theft',
        icon: Icons.report_outlined,
      ),
      (
        category: EmergencyCategory.flightDisruption,
        guideSlug: 'flight-disruption',
        icon: Icons.flight_class,
      ),
      (
        category: EmergencyCategory.cardBlocked,
        guideSlug: 'lost-bank-card',
        icon: Icons.credit_card_off_outlined,
      ),
      (
        category: EmergencyCategory.lostMedication,
        guideSlug: 'lost-medication',
        icon: Icons.medication_outlined,
      ),
      (
        category: EmergencyCategory.noAccommodation,
        guideSlug: 'no-accommodation',
        icon: Icons.night_shelter_outlined,
      ),
      (
        category: EmergencyCategory.arrest,
        guideSlug: 'arrest',
        icon: Icons.gavel_outlined,
      ),
      (
        category: EmergencyCategory.disaster,
        guideSlug: 'natural-disaster',
        icon: Icons.thunderstorm_outlined,
      ),
      (
        category: EmergencyCategory.scam,
        guideSlug: 'scam',
        icon: Icons.privacy_tip_outlined,
      ),
      (
        category: EmergencyCategory.personalSafety,
        guideSlug: 'personal-safety',
        icon: Icons.shield_outlined,
      ),
      (
        category: EmergencyCategory.consular,
        guideSlug: 'lost-passport-abroad',
        icon: Icons.account_balance_outlined,
      ),
    ];

/// Countries with curated, traceable contacts in the bundled offline copy.
const List<({String code, String name})> kSupportedCountries =
    <({String code, String name})>[
      (code: 'HK', name: 'Hong Kong SAR'),
      (code: 'JP', name: 'Japan'),
      (code: 'SG', name: 'Singapore'),
      (code: 'GB', name: 'United Kingdom'),
      (code: 'US', name: 'United States'),
      (code: 'IN', name: 'India'),
      (code: 'AU', name: 'Australia'),
      (code: 'DE', name: 'Germany'),
    ];

/// Bundled emergency contacts for offline use.
///
/// This is a SUBSET of the server registry, with identical source URLs and
/// identical verification state. Every entry is `unverified` until a reviewer
/// checks it against the official page — nothing here can be treated as
/// confirmed, and each row carries the source so the user can check it
/// themselves.
final Map<String, List<EmergencyResource>>
kBundledEmergencyContacts = <String, List<EmergencyResource>>{
  'HK': <EmergencyResource>[
    EmergencyResource(
      id: 'bundled-hk-police-999',
      countryCode: 'HK',
      countryName: 'Hong Kong SAR',
      category: 'police',
      serviceName: 'Police, fire and ambulance (999 — emergency)',
      phone: '999',
      officialUrl: 'https://www.police.gov.hk/en/contact/index.html',
      languages: <String>['English', '中文', '繁體'],
      hours: '24 hours',
      availabilityNote:
          '999 is the single emergency line for police, fire services and ambulance in the '
          'Hong Kong SAR. 112 also connects to emergency services.',
      sourceUrl: 'https://www.police.gov.hk/en/contact/index.html',
      sourceOrg: 'Hong Kong Police Force',
    ),
    EmergencyResource(
      id: 'bundled-hk-ambulance',
      countryCode: 'HK',
      countryName: 'Hong Kong SAR',
      category: 'ambulance',
      serviceName: 'Ambulance (999 — emergency)',
      phone: '999',
      officialUrl: 'https://www.hkfsd.gov.hk/english/contactus/contactus.html',
      languages: <String>['English', '中文', '繁體'],
      hours: '24 hours',
      sourceUrl: 'https://www.hkfsd.gov.hk/english/contactus/contactus.html',
      sourceOrg: 'Hong Kong Fire Services Department',
    ),
    EmergencyResource(
      id: 'bundled-hk-immigration',
      countryCode: 'HK',
      countryName: 'Hong Kong SAR',
      category: 'immigration',
      serviceName: 'Immigration Department enquiries',
      phone: '2824 6111',
      officialUrl: 'https://www.immd.gov.hk/eng/services/contact.html',
      languages: <String>['English', '中文', '繁體'],
      hours: '24 hours for the general enquiries line',
      sourceUrl: 'https://www.immd.gov.hk/eng/services/contact.html',
      sourceOrg: 'Hong Kong Immigration Department',
    ),
    EmergencyResource(
      id: 'bundled-hk-consular',
      countryCode: 'HK',
      countryName: 'Hong Kong SAR',
      category: 'consular_directory',
      serviceName: 'Consular contacts directory',
      officialUrl: 'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit/consular-contacts.html',
      languages: <String>['English', '中文', '繁體'],
      availabilityNote:
          'Official directory of foreign consulates in the Hong Kong SAR. Not every country '
          'maintains a resident mission here; some are accredited from another city.',
      sourceUrl: 'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit/consular-contacts.html',
      sourceOrg: 'Hong Kong Immigration Department',
    ),
  ],
  'JP': <EmergencyResource>[
    EmergencyResource(
      id: 'bundled-jp-police',
      countryCode: 'JP',
      countryName: 'Japan',
      category: 'police',
      serviceName: 'Police (110)',
      phone: '110',
      officialUrl: 'https://www.npa.go.jp/english/',
      languages: <String>['日本語', 'English'],
      hours: '24 hours',
      sourceUrl: 'https://www.npa.go.jp/english/',
      sourceOrg: 'National Police Agency of Japan',
    ),
    EmergencyResource(
      id: 'bundled-jp-ambulance',
      countryCode: 'JP',
      countryName: 'Japan',
      category: 'ambulance',
      serviceName: 'Fire and ambulance (119)',
      phone: '119',
      officialUrl:
          'https://www.fdma.go.jp/mission/prepare/119/english/index.html',
      languages: <String>['日本語', 'English'],
      hours: '24 hours',
      sourceUrl:
          'https://www.fdma.go.jp/mission/prepare/119/english/index.html',
      sourceOrg: 'Japan Fire and Disaster Management Agency',
    ),
  ],
  'SG': <EmergencyResource>[
    EmergencyResource(
      id: 'bundled-sg-police',
      countryCode: 'SG',
      countryName: 'Singapore',
      category: 'police',
      serviceName: 'Police (999)',
      phone: '999',
      officialUrl: 'https://www.police.gov.sg/Contact-Us',
      languages: <String>['English', '中文', 'Bahasa Melayu', 'தமிழ்'],
      hours: '24 hours',
      availabilityNote: 'Ambulance and fire services in Singapore use 995.',
      sourceUrl: 'https://www.police.gov.sg/Contact-Us',
      sourceOrg: 'Singapore Police Force',
    ),
  ],
  'GB': <EmergencyResource>[
    EmergencyResource(
      id: 'bundled-gb-emergency',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      category: 'emergency',
      serviceName: 'Police, ambulance and fire (999)',
      phone: '999',
      officialUrl: 'https://www.gov.uk/guidance/999-and-112-the-uks-national-emergency-numbers',
      languages: <String>['English'],
      hours: '24 hours',
      availabilityNote: '112 also connects to the same emergency services.',
      sourceUrl: 'https://www.gov.uk/guidance/999-and-112-the-uks-national-emergency-numbers',
      sourceOrg: 'UK Government (GOV.UK)',
    ),
  ],
  'US': <EmergencyResource>[
    EmergencyResource(
      id: 'bundled-us-emergency',
      countryCode: 'US',
      countryName: 'United States',
      category: 'police',
      serviceName: 'Police, ambulance and fire (911)',
      phone: '911',
      officialUrl: 'https://www.911.gov/',
      languages: <String>['English', 'Español'],
      hours: '24 hours',
      sourceUrl: 'https://www.911.gov/',
      sourceOrg: 'National Emergency Number System',
    ),
  ],
  'IN': <EmergencyResource>[
    EmergencyResource(
      id: 'bundled-in-emergency',
      countryCode: 'IN',
      countryName: 'India',
      category: 'emergency',
      serviceName: 'Police, ambulance, fire and disaster (112)',
      phone: '112',
      officialUrl: 'https://www.indiacode.nic.in/',
      languages: <String>['English', 'हिन्दी'],
      hours: '24 hours',
      availabilityNote:
          'Integrated national emergency number; state coverage varies.',
      sourceUrl: 'https://www.indiacode.nic.in/',
      sourceOrg: 'Government of India',
    ),
  ],
  'AU': <EmergencyResource>[
    EmergencyResource(
      id: 'bundled-au-emergency',
      countryCode: 'AU',
      countryName: 'Australia',
      category: 'police',
      serviceName: 'Police, ambulance and fire (000)',
      phone: '000',
      officialUrl: 'https://www.triplezero.gov.au/',
      languages: <String>['English'],
      hours: '24 hours',
      availabilityNote: '112 also works from mobile phones in Australia.',
      sourceUrl: 'https://www.triplezero.gov.au/',
      sourceOrg: 'Australian Government — Triple Zero',
    ),
  ],
  'DE': <EmergencyResource>[
    EmergencyResource(
      id: 'bundled-de-police',
      countryCode: 'DE',
      countryName: 'Germany',
      category: 'police',
      serviceName: 'Police (110)',
      phone: '110',
      officialUrl:
          'https://www.bundespolizei.de/EN/Websites/contact/contact-node.html',
      languages: <String>['Deutsch', 'English'],
      hours: '24 hours',
      availabilityNote:
          'Emergency medical and fire services in Germany use 112.',
      sourceUrl:
          'https://www.bundespolizei.de/EN/Websites/contact/contact-node.html',
      sourceOrg: 'Federal Criminal Police Office (BKA)',
    ),
  ],
};

/// Bundled offline guides.
///
/// Content is generic, procedurally correct guidance. Specific phone numbers
/// are deliberately NOT duplicated here: they are looked up at runtime from
/// [kBundledEmergencyContacts] or the server, so a correction in one place
/// fixes every screen.
final List<EmergencyGuide> kBundledGuides = <EmergencyGuide>[
  EmergencyGuide(
    id: 'bundled-lost-passport-abroad',
    slug: 'lost-passport-abroad',
    title: 'Lost or stolen passport abroad',
    summary:
        'A step-by-step plan that works in any country: get safe, report to the police, '
        'contact your embassy, prepare replacement documents and sort out your travel home.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Get to safety first',
        body:
            'Move to a well-lit, staffed place such as a hotel lobby, a café, a shop, a '
            'hospital waiting area or a police station. If you are in immediate danger, '
            'call the local emergency number now. Do not confront or chase anyone you '
            'suspect of taking your belongings.',
        callouts: <String>[
          'Your safety comes before your belongings.',
          'A police report is useful, but it does not replace a travel document.',
        ],
      ),
      GuideStep(
        heading: '2. Report to the police',
        body:
            'Go to a police station, or ask authorised staff — hotel reception, an airport '
            'or station police desk, a tour operator — to help you reach the police. Report '
            'the loss or theft and ask for an incident reference number in writing; you '
            'will usually need it for the embassy.',
        actions: <GuideAction>[
          GuideAction(
            label: 'Find a police station on a map',
            url: 'https://www.openstreetmap.org/search?query=police',
            kind: 'map',
          ),
        ],
        callouts: <String>[
          'If your phone is gone too, ask the station for a written copy of the reference '
              'number before you leave.',
        ],
      ),
      GuideStep(
        heading: '3. Contact your embassy or consulate',
        body:
            'Contact the embassy or consulate of the country whose passport you hold — not '
            'the country you normally live in. Some countries have no embassy in your '
            'current location and use an honorary consulate or a mission accredited from a '
            'neighbouring country. Your home country\'s foreign ministry directory will tell '
            'you which arrangement applies.',
        actions: <GuideAction>[
          GuideAction(
            label: 'Open an embassy directory',
            url: 'https://www.consularhelp.dfa.gov.au/',
            kind: 'external',
          ),
        ],
        callouts: <String>[
          'Ask specifically about an emergency travel document, a temporary passport or a '
              'replacement passport. What is available differs by nationality and '
              'jurisdiction — the consular office decides what it can issue.',
          'Some embassies only issue emergency documents to nationals who are stranded. A '
              'valid onward ticket and proof of residence are commonly required.',
        ],
      ),
      GuideStep(
        heading: '4. Put replacement documents together',
        body:
            'Collect what you can and keep digital copies. The exact list is set by your '
            'embassy, so confirm it with them rather than assuming.',
        callouts: <String>[
          'Police report or incident reference number, if you have one',
          'Alternative proof of identity, such as a driving licence or national ID card',
          'Passport copy or passport number, if available',
          'Passport photographs, if the embassy requests them',
          'Proof of citizenship or nationality, if requested',
          'Flight itinerary or booking reference',
          'Accommodation details',
          'Completed application forms and the applicable fee',
        ],
      ),
      GuideStep(
        heading: '5. Contact your airline',
        body:
            'Call the airline before you go to the airport. Explain what has happened and '
            'ask what they will accept. Airlines may require a specific document type '
            'before they will let you board.',
        callouts: <String>[
          'No airline can promise boarding without a valid travel document. Whether a '
              'specific document is acceptable is decided by the airline, per route.',
          'Check every transit country as well as the destination — a journey can fail on '
              'transit rules rather than at the final destination.',
          'Ask whether the existing ticket can be reissued rather than repurchased.',
        ],
      ),
      GuideStep(
        heading: '6. Get home safely',
        body:
            'Ask your consular service what travel document you need and what the exit '
            'requirements are for your nationality. Then rebook flights, arrange temporary '
            'accommodation and keep every receipt.',
        callouts: <String>[
          'Confirm entry requirements for your destination and every transit country.',
          'Ask whether an exit permit, visa replacement or additional local procedure applies.',
          'Keep copies of every police report and every message from the embassy.',
          'If you need emergency funds, your embassy or insurer may be able to advise on '
              'documented emergency assistance.',
        ],
      ),
    ],
    phrases: const <String, List<String>>{
      'en': <String>[
        'Excuse me, I need help. My passport has been lost or stolen.',
        'I need a police report. Could I have an incident reference number, please?',
        'Which embassy or consulate can help me?',
        'I need an emergency travel document to get home.',
        'Could I have a receipt, please? This is for my insurance claim.',
      ],
      'zh-Hant': <String>[
        '你好，我需要幫助。我的護照遺失了。',
        '你好，我需要幫助。我的護照被盜了。',
        '我要報警遺失護照，可以給我一個報案編號嗎？',
        '哪一個使領館可以幫助我？',
        '我需要旅行證件或臨時護照回家。',
      ],
      'es': <String>[
        'Disculpe, necesito ayuda. He perdido o me han robado el pasaporte.',
        'Necesito poner una denuncia. ¿Pueden darme un número de referencia, por favor?',
      ],
      'fr': <String>[
        'Excusez-moi, j\'ai besoin d\'aide. Mon passeport a été perdu ou volé.',
        'J\'ai besoin de faire un signalement. Puis-je avoir un numéro de référence ?',
      ],
      'de': <String>[
        'Entschuldigen Sie, ich brauche Hilfe. Mein Pass ist verloren oder gestohlen.',
        'Ich brauche eine Polizeianzeige. Können Sie mir bitte eine Referenznummer geben?',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-lost-wallet',
    slug: 'lost-wallet',
    title: 'Lost or stolen wallet',
    summary:
        'Block your cards quickly, report the loss, and think about how you will access '
        'money safely for the rest of the trip.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Block your bank cards now',
        body:
            'Call your bank using the number printed on the card or in the banking app — '
            'not a number from an email, a text message or a search result. Banks can '
            'freeze a card immediately and issue a replacement.',
        callouts: <String>[
          'TripSplit never stores card numbers, PINs or online banking credentials. It '
              'can only link out to your provider\'s own site.',
        ],
      ),
      GuideStep(
        heading: '2. Report the loss or theft',
        body:
            'Report the loss to the police if you suspect theft, and keep the incident '
            'reference number. Your insurer will usually ask for it before paying out a '
            'cash or card claim.',
      ),
      GuideStep(
        heading: '3. Check what is missing',
        body:
            'Note every card, document and key that was in the wallet. This list is what '
            'you will need for the police report and for cancelling items.',
      ),
      GuideStep(
        heading: '4. Access money safely',
        body:
            'Ask your bank what emergency options exist, such as a temporary card, a cash '
            'advance at a branch, or a transfer to a trusted person. Withdraw from an '
            'ATM operated by your own bank where possible.',
        callouts: <String>[
          'Keep receipts for anything you spend replacing the wallet — an insurance claim '
              'usually needs them.',
        ],
      ),
    ],
    phrases: const <String, List<String>>{
      'en': <String>[
        'I have lost my wallet. I need to block my cards.',
        'Where is the nearest branch of my bank?',
        'Can I get an emergency cash withdrawal?',
      ],
      'zh-Hant': <String>['我的錢包不見了，我需要暫停我的卡。', '我的銀行分行在哪裡？', '我可以緊急取現嗎？'],
      'es': <String>[
        'He perdido mi cartera. Necesito bloquear mis tarjetas.',
        '¿Dónde está la sucursal de mi banco más cercana?',
      ],
      'fr': <String>[
        'J\'ai perdu mon portefeuille. Je dois bloquer mes cartes.',
        'Où se trouve la succursale de ma banque la plus proche ?',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-lost-phone',
    slug: 'lost-phone',
    title: 'Lost phone',
    summary:
        'Secure your accounts, block the SIM, and protect the payment methods and email '
        'that were on the device.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Secure your accounts first',
        body:
            'Someone with your unlocked phone can do a lot of harm. On another device, '
            'change the password for your email account first — email is the account that '
            'can reset everything else.',
      ),
      GuideStep(
        heading: '2. Use the device-finding service',
        body:
            'Apple and Google both provide a device-finding service that can show the last '
            'known location, play a sound, and in some cases lock or erase the device.',
        actions: <GuideAction>[
          GuideAction(
            label: 'Apple Find My iPhone',
            url: 'https://www.icloud.com/find',
            kind: 'external',
          ),
          GuideAction(
            label: 'Google Find Hub',
            url: 'https://www.google.com/android/find',
            kind: 'external',
          ),
        ],
        callouts: <String>[
          'Only use these links typed directly. Scammers send fake "your phone has been '
              'found, click here" messages.',
        ],
      ),
      GuideStep(
        heading: '3. Block the SIM',
        body:
            'Contact your mobile carrier to block the SIM and the phone number so it cannot '
            'be used for calls or for SMS-based two-factor codes.',
      ),
      GuideStep(
        heading: '4. Protect what was on the device',
        body:
            'Change passwords for email, banking and any account that used the phone number '
            'for two-factor authentication. Revoke any sessions you do not recognise.',
        callouts: <String>[
          'Never share a one-time password with anyone, including someone claiming to be '
              'your bank or your employer.',
        ],
      ),
      GuideStep(
        heading: '5. Consider the SIM-swap risk',
        body:
            'If someone replaces the SIM in your name, your carrier should notice. If your '
            'number stops working unexpectedly, contact your carrier urgently and ask them '
            'to put a lock on the account.',
      ),
    ],
    phrases: const <String, List<String>>{
      'en': <String>[
        'I have lost my phone and need to block the SIM.',
        'Please suspend this number. I have lost the device.',
      ],
      'zh-Hant': <String>['我的手機不見了，我需要停用手機號碼。', '請暫停這個號碼，裝置已經遺失。'],
      'es': <String>['He perdido mi teléfono y necesito bloquear la SIM.'],
      'fr': <String>['J\'ai perdu mon téléphone et je dois bloquer la SIM.'],
    },
  ),
  EmergencyGuide(
    id: 'bundled-lost-bank-card',
    slug: 'lost-bank-card',
    title: 'Lost or stolen bank card',
    summary: 'Freeze the card, then replace it. What to do depends on where you are.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Freeze the card immediately',
        body:
            'Call the number printed on the card, or the one in your banking app. If the '
            'card was taken rather than lost, tell the bank it was stolen so they can '
            'also flag the transactions as fraudulent.',
        callouts: <String>[
          'Only use contact details printed on the card or shown in the official app. '
              'Never use a number from an unsolicited message.',
        ],
      ),
      GuideStep(
        heading: '2. Ask about a temporary card',
        body:
            'Most banks can issue a replacement quickly. If you are abroad, ask whether '
            'they can send it to your current address or to a branch you can reach.',
      ),
      GuideStep(
        heading: '3. Watch your statements',
        body:
            'Check for transactions you did not make and report them immediately. Record '
            'the dates and amounts — your insurer or the bank will ask for them.',
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'I have lost my bank card. Please block it.',
        'Where is the nearest branch of my bank?',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-medical-emergency',
    slug: 'medical-emergency',
    title: 'Medical emergency',
    summary:
        'Get to care, and let your insurer know early — they arrange treatment and handle '
        'payment directly.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Get to care',
        body:
            'Call the local emergency number or go to the nearest hospital emergency '
            'department. Do not delay seeking care to sort out payment first.',
      ),
      GuideStep(
        heading: '2. Contact your travel insurance early',
        body:
            'Most policies require you to contact the assistance line as soon as possible, '
            'and often before admission unless it is a life-threatening emergency. They '
            'may guarantee payment to the hospital directly.',
        callouts: <String>[
          'TripSplit can store the assistance number you supply, but it cannot verify your '
              'cover or confirm what will be paid. Always confirm eligibility and terms '
              'with your insurer.',
        ],
      ),
      GuideStep(
        heading: '3. Keep records',
        body:
            'Keep every invoice, prescription, diagnosis letter and receipt. Keep a written '
            'note of what happened and when, including who you spoke to.',
      ),
      GuideStep(
        heading: '4. If you take regular medication',
        body:
            'Ask the pharmacist or doctor for a generic equivalent, and keep the packaging. '
            'If your supply has run out, a pharmacist can often advise on an equivalent '
            'while you find a supply.',
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'I need a doctor. Please call an ambulance.',
        'Where is the nearest hospital?',
        'I need to contact my travel insurance.',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-lost-medication',
    slug: 'lost-medication',
    title: 'Lost medication',
    summary: 'Getting a replacement abroad is usually possible, but not always quick.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Ask a local pharmacist or doctor',
        body:
            'A pharmacist can often tell you whether an equivalent is available over the '
            'counter and provide a written generic name you can show elsewhere.',
      ),
      GuideStep(
        heading: '2. Bring proof of your prescription',
        body:
            'A prescription copy, a photo of the packaging, or a letter from your regular '
            'doctor naming the generic drug and dose is usually enough for a local doctor '
            'to prescribe.',
      ),
      GuideStep(
        heading: '3. Contact your insurer or consulate if it is urgent',
        body:
            'For controlled or specialist medication, your insurer or your embassy may be '
            'able to help you find a supply or arrange a prescription from home.',
        callouts: <String>[
          'Never buy a prescription medicine from an informal seller.',
        ],
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'I have lost my medication. Can you help me get a replacement?',
        'I have a prescription for this medicine.',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-theft',
    slug: 'theft',
    title: 'Theft or robbery',
    summary: 'Get safe, report it, and protect the accounts and documents that were taken.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Get to safety',
        body:
            'Move somewhere staffed and lit. Do not follow or confront anyone. If you are '
            'being followed, go into a shop, a café or a police station and ask them to '
            'call the police.',
      ),
      GuideStep(
        heading: '2. Report it',
        body:
            'Report the theft to the police and get an incident reference number. Your '
            'insurer will require it for any claim.',
        callouts: <String>[
          'If your passport was taken, follow the lost-passport guide as well — the police '
              'report serves both.',
        ],
      ),
      GuideStep(
        heading: '3. Block and change',
        body:
            'Block any bank cards that were taken and change passwords for anything that '
            'was unlocked or in view.',
      ),
      GuideStep(
        heading: '4. Keep the evidence',
        body:
            'Keep receipts for anything you have to replace, note the time and place, and '
            'keep the reference number. Photograph any injuries.',
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'I have been robbed. I need the police.',
        'I need an incident reference number, please.',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-flight-disruption',
    slug: 'flight-disruption',
    title: 'Cancelled flight or missed connection',
    summary: 'Your rights depend on where you are, but the airline normally has to help.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Go to the airline desk',
        body:
            'Speak to the airline, not only to the airport. Ask what your options are: '
            'rebooking, a hotel, meals, and whether the cause was within your control.',
      ),
      GuideStep(
        heading: '2. Keep every receipt',
        body:
            'Keep receipts for food, hotel and transport. If the airline pays you back, '
            'they will usually want the receipts.',
        callouts: <String>[
          'Compensation rules differ by country and by route. TripSplit cannot tell you '
              'what you are entitled to — check your airline\'s policy and the local '
              'consumer-protection authority.',
        ],
      ),
      GuideStep(
        heading: '3. If you need to rebook yourself',
        body:
            'Pay for a replacement yourself only if you have to, and keep the receipt and '
            'the booking confirmation. Most airlines reimburse reasonable costs when the '
            'cancellation is their responsibility.',
      ),
      GuideStep(
        heading: '4. Check onward travel documents',
        body:
            'If the delay pushes you into a different visa window or a transit country, '
            'check whether your travel authorisation is still valid for the new dates.',
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'My flight was cancelled. What are my options?',
        'Can I have a receipt for this?',
        'I need help rebooking.',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-no-accommodation',
    slug: 'no-accommodation',
    title: 'Nowhere to stay tonight',
    summary: 'There are options, but they depend on where you are and what you can afford.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Call ahead',
        body:
            'Before walking around, call nearby hotels or hostels and ask whether they '
            'have a room that night. Many will hold a room if you explain the situation.',
      ),
      GuideStep(
        heading: '2. Ask at a hospital or embassy',
        body:
            'In some places a hospital or a consular waiting area can point you towards '
            'cheap or emergency accommodation. An embassy will not put you up, but staff '
            'often know local options.',
      ),
      GuideStep(
        heading: '3. Use legitimate overnight services',
        body:
            'Hostels, budget hotels, airport transit hotels and faith- or community-based '
            'refuges are the usual fallback. Avoid unlicensed private "hostels" that ask '
            'for cash up front with no address.',
        callouts: <String>[
          'Never pay a deposit to someone who will not give you a written receipt and an '
              'exact address.',
        ],
      ),
      GuideStep(
        heading: '4. Tell someone where you are',
        body:
            'Message a person at home with the address of where you are staying, and keep '
            'your phone charged.',
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'I need a room for tonight. Do you have one?',
        'I have no accommodation tonight.',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-arrest',
    slug: 'arrest',
    title: 'Arrest or detention',
    summary:
        'Stay calm, do not resist, and ask for contact with your embassy. Know your rights '
        'before you travel.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Stay calm and cooperate',
        body:
            'Do not resist, argue or sign anything you do not understand. Signing a document '
            'in a language you cannot read can waive rights you do not know you have.',
      ),
      GuideStep(
        heading: '2. Ask to contact your embassy',
        body:
            'Ask the officers to contact your embassy or consulate. In most countries you '
            'have a right to consular access, though the exact rules vary.',
        callouts: <String>[
          'A consular officer can advise and, where permitted, intervene — but they cannot '
              'get you released if the local law does not allow it.',
        ],
      ),
      GuideStep(
        heading: '3. Ask for a record',
        body:
            'Ask to be given a copy of anything you are asked to sign, and note the names '
            'or badge numbers of the officers involved.',
      ),
      GuideStep(
        heading: '4. Do not sign a statement in a hurry',
        body:
            'If you are asked to make a statement, ask for it in a language you understand. '
            'You can ask for time to consult a lawyer.',
        callouts: <String>[
          'TripSplit cannot give legal advice. A local lawyer or your embassy is the right '
              'source.',
        ],
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'I would like to contact my embassy.',
        'I do not understand this document.',
        'I request a lawyer.',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-natural-disaster',
    slug: 'natural-disaster',
    title: 'Natural disaster',
    summary: 'Follow official alerts, and do not return to an affected area until cleared.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Follow official alerts',
        body:
            'Your government\'s foreign travel advice site and the local meteorological or '
            'emergency agency are the authoritative sources. Social media is often faster '
            'but often wrong.',
        actions: <GuideAction>[
          GuideAction(
            label: 'Your government travel advice',
            url: 'https://www.gov.uk/foreign-travel-advice',
            kind: 'external',
          ),
        ],
      ),
      GuideStep(
        heading: '2. Move away from the hazard',
        body:
            'For an earthquake, drop, cover and hold on, then move to open ground. For a '
            'flood, go to higher ground, never to an underpass or a basement. For a '
            'wildfire, move away from the direction of travel of the smoke.',
      ),
      GuideStep(
        heading: '3. Do not return early',
        body:
            'Aftershocks, secondary collapse and closed roads are common reasons people are '
            'hurt after the initial event. Wait for the official all-clear.',
      ),
      GuideStep(
        heading: '4. Contact your insurer',
        body:
            'Many policies cover cancellation or curtailment for a natural disaster. Tell '
            'them as soon as you can, and keep every receipt.',
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'There is an emergency here. We need help.',
        'Where is the nearest shelter?',
        'Is it safe to go back to my accommodation?',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-scam',
    slug: 'scam',
    title: 'You think you have been scammed',
    summary: 'Act fast on the money, and slowly on anything that asks for your identity.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Stop the payment',
        body:
            'If you have just paid, call your bank immediately and ask them to recall the '
            'payment. The sooner you call, the better the chance of recovery.',
      ),
      GuideStep(
        heading: '2. Do not send anything else',
        body:
            'Many scams follow up with a "recovery agent" who asks for an upfront fee. '
            'There is no reputable service that can recover money for a fee paid upfront.',
      ),
      GuideStep(
        heading: '3. Preserve the evidence',
        body:
            'Keep the messages, the transaction reference, screenshots and any phone numbers. '
            'Report it to your bank and to the local police or fraud reporting service.',
      ),
      GuideStep(
        heading: '4. Secure your accounts',
        body:
            'If you shared card details, block the card. If you shared an identity document, '
            'contact the issuing authority and ask what to do.',
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'I think I have been scammed.',
        'I need to call my bank about this payment.',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-personal-safety',
    slug: 'personal-safety',
    title: 'Personal safety emergency',
    summary:
        'Prioritise getting somewhere safe, then tell someone where you are.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Get to a public, staffed place',
        body:
            'A café, shop, hotel lobby, hospital, police station, place of worship or a '
            'crowded transport hub. Being surrounded by people is the single most '
            'effective protection.',
      ),
      GuideStep(
        heading: '2. Call the local emergency number',
        body:
            'If you are in immediate danger, call the local emergency number. Staff at a '
            'nearby business will often call on your behalf if you cannot.',
      ),
      GuideStep(
        heading: '3. Tell someone you trust',
        body:
            'Send your live location to a person at home. If you can, send the name of the '
            'place you are in.',
      ),
      GuideStep(
        heading: '4. If it is not an emergency but you feel unsafe',
        body:
            'Leave the situation. Return to your accommodation, or to a staffed place, and '
            'decide tomorrow what you want to do about it. If someone is stalking you, '
            'tell the police and a person at home.',
        callouts: <String>[
          'If you are a traveller and this is happening far from home, your embassy or '
              'consulate can help you make arrangements to get home safely.',
        ],
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'I do not feel safe here. Can you help me?',
        'Please call the police.',
        'I need to contact someone at home.',
      ],
    },
  ),
  EmergencyGuide(
    id: 'bundled-hong-kong',
    slug: 'lost-passport-hong-kong',
    countryCode: 'HK',
    title: 'Lost or stolen passport in Hong Kong',
    summary:
        'The standard lost-passport procedure with the Hong Kong SAR contacts and '
        'Traditional Chinese phrasing. Confirm every number on the official Hong Kong '
        'Police or Immigration page before relying on it.',
    steps: <GuideStep>[
      GuideStep(
        heading: '1. Are you in immediate danger?',
        body:
            'In the Hong Kong SAR, 999 reaches police, fire services and ambulance. 112 '
            'also connects to the same emergency services. Move to a staffed, well-lit '
            'place such as a hotel lobby, a shopping centre, a hospital or a police '
            'station.',
        actions: <GuideAction>[
          GuideAction(label: 'Call 999', url: 'tel:999', kind: 'call'),
        ],
        callouts: <String>[
          'Do not confront anyone you suspect. Show someone on this screen the phrase '
              '"請務僕叫譚巴" if you cannot speak the local language.',
        ],
      ),
      GuideStep(
        heading: '2. Report the loss or theft to the police',
        body:
            'Ask your hotel, MTR staff, a shop or a police station to help you reach the '
            'police. Report the loss and request an incident reference number � you will '
            'need it for the Immigration Department and for your consulate.',
        actions: <GuideAction>[
          GuideAction(
            label: 'Find a police station on a map',
            url: 'https://www.openstreetmap.org/search?query=police%20station%20Hong%20Kong',
            kind: 'map',
          ),
          GuideAction(
            label: 'Hong Kong Police contact page',
            url: 'https://www.police.gov.hk/en/contact/index.html',
            kind: 'external',
          ),
        ],
        callouts: <String>[
          '999 is for emergencies. For a loss that is not in progress, use the published '
              'non-emergency line.',
          'A police report does not replace a travel document.',
        ],
      ),
      GuideStep(
        heading: '3. Reach the right embassy or consulate',
        body:
            'Find the mission that covers your nationality. Not every country maintains '
            'a resident consulate in the Hong Kong SAR � some are represented by an '
            'honorary consulate or a mission accredited from another city. The Hong Kong '
            'Immigration Department publishes a consular contacts directory.',
        actions: <GuideAction>[
          GuideAction(
            label: 'Hong Kong Immigration consular contacts directory',
            url: 'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit/consular-contacts.html',
            kind: 'external',
          ),
        ],
        callouts: <String>[
          'Availability and procedure are decided by your own government, not by Hong Kong.',
          'If your mission is not in Hong Kong, they will tell you which office to contact.',
        ],
      ),
      GuideStep(
        heading: '4. Prepare what the embassy asks for',
        body: 'Confirm the exact list with your own consular service before you go anywhere.',
        callouts: <String>[
          'Police report or incident reference number',
          'Alternative identity document',
          'Passport copy or passport number if you have it',
          'Passport photographs if requested',
          'Proof of citizenship or nationality if requested',
          'Flight itinerary or booking reference',
          'Accommodation details',
          'Completed forms and the fee',
        ],
      ),
      GuideStep(
        heading: '5. Contact your airline before going to the airport',
        body:
            'Call the airline and explain the situation. Confirm what document they will '
            'accept for your specific route.',
        callouts: <String>[
          'An airline cannot promise boarding without an acceptable travel document.',
          'Check transit-country rules as well as your destination � Hong Kong may be your '
              'transit point rather than your destination.',
        ],
      ),
      GuideStep(
        heading: '6. Leaving Hong Kong and getting home',
        body:
            'Confirm with your consular service what you need for the exit and for boarding '
            'at home.',
        callouts: <String>[
          'Keep every receipt and every copy of your police report.',
          'If you need emergency funds, ask your consular service or your insurer what '
              'documented assistance is available.',
        ],
      ),
    ],
    phrases: <String, List<String>>{
      'en': <String>[
        'Excuse me, I need help. My passport has been lost or stolen.',
        'I need to report a lost passport. Could I have an incident reference number?',
        'Which embassy or consulate can assist me?',
        'I need an emergency travel document.',
        'Please call an ambulance.',
        'Please call the police.',
      ],
      'zh-Hant': <String>[
        '你好，我需要幫助。我的護照遺失了。',
        '你好，我需要幫助。我的護照被盜了。',
        '我要報警遺失護照，可以給我一個報案編號嗎？',
        '哪一個使領館可以幫助我？',
        '我需要旅行證件或臨時護照回家。',
        '請幫我叫救護車。',
        '請幫我叫警察。',
      ],
    },
  ),
];
