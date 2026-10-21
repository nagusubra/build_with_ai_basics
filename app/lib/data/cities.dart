/// Cities people pick from at sign-up, so the location filter compares like with like.
/// Stored on the profile exactly as listed ("City, Country").
const _byCountry = {
  'UK': [
    'Aberdeen', 'Bath', 'Belfast', 'Birmingham', 'Brighton', 'Bristol', 'Cambridge', 'Cardiff', 'Coventry',
    'Derby', 'Dundee', 'Edinburgh', 'Exeter', 'Glasgow', 'Inverness', 'Leeds', 'Leicester', 'Liverpool',
    'London', 'Manchester', 'Milton Keynes', 'Newcastle', 'Norwich', 'Nottingham', 'Oxford', 'Perth',
    'Plymouth', 'Portsmouth', 'Reading', 'Sheffield', 'Southampton', 'St Andrews', 'Stirling', 'Swansea', 'York',
  ],
  'Ireland': ['Cork', 'Dublin', 'Galway', 'Limerick', 'Waterford'],
  'Canada': [
    'Calgary', 'Edmonton', 'Halifax', 'Hamilton', 'Kelowna', 'Kingston', 'Kitchener', 'Lethbridge', 'London',
    'Mississauga', 'Montreal', 'Ottawa', 'Quebec City', 'Red Deer', 'Regina', 'Saskatoon', 'Toronto',
    'Vancouver', 'Victoria', 'Waterloo', 'Winnipeg',
  ],
  'US': [
    'Atlanta', 'Austin', 'Boston', 'Chicago', 'Dallas', 'Denver', 'Detroit', 'Houston', 'Las Vegas',
    'Los Angeles', 'Miami', 'Minneapolis', 'Nashville', 'New York', 'Philadelphia', 'Phoenix', 'Pittsburgh',
    'Portland', 'San Diego', 'San Francisco', 'San Jose', 'Seattle', 'Washington DC',
  ],
  'India': [
    'Ahmedabad', 'Bengaluru', 'Bhopal', 'Chandigarh', 'Chennai', 'Delhi', 'Goa', 'Gurugram', 'Hyderabad',
    'Indore', 'Jaipur', 'Kochi', 'Kolkata', 'Lucknow', 'Mumbai', 'Noida', 'Pune', 'Surat',
  ],
  'Australia': ['Adelaide', 'Brisbane', 'Canberra', 'Darwin', 'Gold Coast', 'Hobart', 'Melbourne', 'Perth', 'Sydney'],
};

final List<String> cities = [
  for (final e in _byCountry.entries)
    for (final c in e.value) '$c, ${e.key}',
];

/// Cities matching [query] by name or country, those starting with it first; everything when it's empty.
List<String> searchCities(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return cities;
  final matches = cities.where((c) => c.toLowerCase().contains(q)).toList();
  return [
    ...matches.where((c) => c.toLowerCase().startsWith(q)),
    ...matches.where((c) => !c.toLowerCase().startsWith(q)),
  ];
}
