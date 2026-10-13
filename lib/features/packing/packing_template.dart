/// Bundled checklist templates.
///
/// These are general reminders, not universal entry requirements. Visa and
/// passport requirements depend on nationality, residence, transit route,
/// purpose and destination, and must be checked against official sources.
class ChecklistTemplate {
  const ChecklistTemplate({
    required this.slug,
    required this.name,
    required this.description,
    required this.items,
  });

  final String slug;
  final String name;
  final String description;
  final List<String> items;
}

const List<ChecklistTemplate> checklistTemplates = <ChecklistTemplate>[
  ChecklistTemplate(
    slug: 'international-travel',
    name: 'International travel',
    description:
        'General pre-departure checks for travelling internationally. Requirements vary by '
        'nationality and destination — confirm with official sources.',
    items: <String>[
      'Valid passport',
      'Passport validity checked against destination entry rules',
      'Blank passport pages available',
      'Visa or eTravel authorisation checked',
      'Visa approved, where one is required',
      'Flight tickets',
      'Return or onward travel arranged',
      'Accommodation confirmations saved offline',
      'Travel insurance purchased, policy number saved',
      'Emergency contacts written down for offline use',
      'Secure digital copy of passport and visa',
      'Health or vaccination documents checked against official guidance',
      'Prescription medicines and supporting documentation packed',
      'Driving permit checked, if driving abroad',
      'Two payment methods prepared',
      'Local SIM or roaming arranged',
      'Power adapter for the destination',
      'Airport transfer booked',
      'Key reservations downloaded for offline access',
    ],
  ),
  ChecklistTemplate(
    slug: 'beach-holiday',
    name: 'Beach holiday',
    description: 'Warm-weather essentials.',
    items: <String>[
      'Swimwear',
      'Light clothing',
      'Sun hat and sunglasses',
      'Reef-safe sunscreen',
      'Flip-flops',
      'Quick-dry towel',
      'Waterproof phone pouch',
      'Insect repellent',
      'After-sun lotion',
      'Power bank',
    ],
  ),
  ChecklistTemplate(
    slug: 'cold-weather',
    name: 'Cold-weather destination',
    description: 'Layering for low temperatures.',
    items: <String>[
      'Thermal base layers',
      'Insulated jacket',
      'Waterproof and windproof outer shell',
      'Warm hat and gloves',
      'Wool socks',
      'Waterproof boots',
      'Lip balm with SPF',
      'Hand warmers',
      'Head torch with spare batteries',
      'Camera spare batteries',
    ],
  ),
  ChecklistTemplate(
    slug: 'business-trip',
    name: 'Business trip',
    description: 'A short professional trip.',
    items: <String>[
      'Laptop and charger',
      'Presentation materials saved offline',
      'Business cards',
      'Formal outfit',
      'Travel insurance with business cover',
      'Meeting locations and addresses saved',
      'Local currency or card ready',
    ],
  ),
  ChecklistTemplate(
    slug: 'family-travel',
    name: 'Family travel',
    description: 'Travelling with children.',
    items: <String>[
      'Passport or birth certificate for each child',
      'Child car seat if required',
      'Favourite snacks and milk',
      'Reusable water bottles',
      'Small first-aid kit',
      'Entertainment for the journey',
      'Nappies and wipes',
      'Comfort objects for bedtime',
    ],
  ),
  ChecklistTemplate(
    slug: 'adventure-trip',
    name: 'Adventure trip',
    description: 'Hiking, climbing or water sports.',
    items: <String>[
      'Broken-in hiking boots',
      'Rain shell',
      'Head torch with spare batteries',
      'Blister plasters and tape',
      'Water purification method',
      'High-energy snacks',
      'Insect repellent',
      'Emergency bivvy or poncho',
      'Offline map of the route',
      'First-aid kit',
    ],
  ),
  ChecklistTemplate(
    slug: 'long-stay',
    name: 'Long stay (over one month)',
    description: 'Extended-stay packing.',
    items: <String>[
      'Prescription cover for the full stay',
      'Laundry detergent',
      'Extra clothing for the full duration',
      'Home SIM paused or forwarded',
      'Storage for excess luggage',
      'Vaccination records',
      'Voltage and plug check for all accommodation',
    ],
  ),
  ChecklistTemplate(
    slug: 'domestic-travel',
    name: 'Domestic travel',
    description: 'A shorter trip within your own country.',
    items: <String>[
      'Photo ID for transport and hotels',
      'Tickets booked',
      'Accommodation confirmation',
      'Phone charged and power bank packed',
      'Water and snacks for the journey',
      'Offline map of the destination',
    ],
  ),
];
