// HACKATHON DEMO — the people judges meet. `seed-judges.mjs` writes them; the web app's judge
// panel (app/lib/services/judge_access.dart) logs into the two `readyMade` ones with this password.
// Everyone here is a sample profile (marked demo), not a real person.
export const JUDGE_PASSWORD = 'BakeOut-judge-2026';

// Judges log into these. They have matched each other, so Cherry's chat is waiting.
export const readyMade = [
  {
    id: 'maya',
    email: 'maya@bakeout.demo',
    name: 'Maya',
    age: 27,
    gender: 'Woman',
    cherry: 'girl',
    city: 'London, UK',
    lookingFor: 'partner',
    photo: { emoji: '🍝', colors: ['#FFB4A2', '#E5989B'] },
    food: {
      cookingRelationship: 'I love cooking and do it almost every day',
      foodType: 'Vegetarian',
      restrictions: [],
      cuisines: ['Italian', 'Indian', 'Japanese', 'Mediterranean', 'Thai'],
      topCuisines: ['Italian', 'Indian', 'Japanese'],
      signatureDish: 'Saffron risotto that converts rice sceptics',
      comfortFood: 'Masala chai and buttery toast',
      adventure: 8,
      idealDate: 'Trying a completely new recipe',
      cookingPersonality: ['The experimental chef'],
      cookingTime: 'Around an hour',
      musicGenres: ['Indie', 'Jazz'],
      favouriteSong: 'Valerie — Amy Winehouse',
    },
    prompts: {
      winMeOverWith: 'Fresh basil from your windowsill and zero judgement about my spice tolerance.',
      cookingDisaster: 'I once set off the fire alarm making toast. At a dinner party. For twelve.',
    },
  },
  {
    id: 'arjun',
    email: 'arjun@bakeout.demo',
    name: 'Arjun',
    age: 29,
    gender: 'Man',
    cherry: 'boy',
    city: 'London, UK',
    lookingFor: 'partner',
    photo: { emoji: '🍛', colors: ['#FFD6A5', '#F4A261'] },
    food: {
      cookingRelationship: 'I cook when I have time',
      foodType: 'Vegetarian',
      restrictions: ['Nut allergy'],
      cuisines: ['Indian', 'Italian', 'Thai', 'Mexican'],
      topCuisines: ['Indian', 'Italian', 'Thai'],
      signatureDish: "Paneer butter masala from my nani's recipe",
      comfortFood: 'Rajma chawal',
      adventure: 7,
      idealDate: 'One person cooks, the other helps',
      cookingPersonality: ['The organised chef'],
      cookingTime: 'Around an hour',
      musicGenres: ['Bollywood', 'Lo-fi'],
      favouriteSong: 'Kesariya — Arijit Singh',
    },
    prompts: {
      dishEveryDay: 'Dal tadka with jeera rice. Every. Single. Day.',
      winMeOverWith: 'A recipe you have never tried and the courage to try it with me.',
    },
  },
];

// Discover's sample crowd. They like judges back (demoLikesBack), so a like becomes a match.
// `likes` names a ready-made account they have already liked, for the "liked you" banner.
const crowdProfiles = [
  {
    id: 'sofia', name: 'Sofia', age: 26, gender: 'Woman', cherry: 'girl', city: 'Edinburgh, UK', lookingFor: 'partner',
    likes: 'arjun',
    photo: { emoji: '🥐', colors: ['#FFE5EC', '#FFB3C6'] },
    food: {
      cookingRelationship: 'I cook when I have time', foodType: 'Pescatarian', restrictions: [],
      cuisines: ['Mediterranean', 'Italian', 'French', 'Japanese'], topCuisines: ['Mediterranean', 'Italian', 'French'],
      signatureDish: 'Lemon and herb baked sea bass', comfortFood: 'Croissants on a rainy Sunday', adventure: 6,
      idealDate: 'Baking something sweet', cookingPersonality: ['The perfectionist'], cookingTime: 'Around an hour',
      musicGenres: ['Jazz', 'Pop'],
    },
  },
  {
    id: 'daniel', name: 'Daniel', age: 31, gender: 'Man', cherry: 'boy', city: 'Manchester, UK', lookingFor: 'partner',
    likes: 'maya',
    photo: { emoji: '🌮', colors: ['#CDEAC0', '#7FB77E'] },
    food: {
      cookingRelationship: 'I love cooking and do it almost every day', foodType: 'I eat pretty much everything', restrictions: [],
      cuisines: ['Mexican', 'Korean', 'American', 'Italian'], topCuisines: ['Mexican', 'Korean', 'Italian'],
      signatureDish: 'Slow-cooked birria tacos', comfortFood: 'Kimchi fried rice', adventure: 9,
      idealDate: 'A friendly cooking competition', cookingPersonality: ['The chaotic chef'],
      cookingTime: 'I could spend the whole evening cooking', musicGenres: ['Hip-hop', 'Rock'],
    },
  },
  {
    id: 'priya', name: 'Priya', age: 25, gender: 'Woman', cherry: 'girl', city: 'Bristol, UK', lookingFor: 'partner',
    photo: { emoji: '🥟', colors: ['#FDE2E4', '#F08080'] },
    food: {
      cookingRelationship: 'I can manage a few basic dishes', foodType: 'Vegetarian', restrictions: ['No onion or garlic'],
      cuisines: ['Indian', 'Chinese', 'Thai', 'Japanese'], topCuisines: ['Indian', 'Chinese', 'Japanese'],
      signatureDish: 'Veg momos with a fiery chutney', comfortFood: 'Khichdi', adventure: 7,
      idealDate: 'Cooking something simple together', cookingPersonality: ['The lazy chef'], cookingTime: 'Around 30 minutes',
      musicGenres: ['Bollywood', 'Pop'],
    },
  },
  {
    id: 'leo', name: 'Leo', age: 28, gender: 'Non-binary', cherry: 'boy', city: 'London, UK', lookingFor: 'partner',
    photo: { emoji: '🍣', colors: ['#D7E3FC', '#9AB6F0'] },
    food: {
      cookingRelationship: "I don't know how to cook, but I'd love to learn", foodType: 'Pescatarian', restrictions: ['Gluten-free'],
      cuisines: ['Japanese', 'Korean', 'Thai', 'Italian'], topCuisines: ['Japanese', 'Korean', 'Italian'],
      signatureDish: 'Hand-rolled salmon temaki', comfortFood: 'Miso soup', adventure: 8,
      idealDate: 'Trying a completely new recipe', cookingPersonality: ['The food critic'], cookingTime: 'Around 30 minutes',
      musicGenres: ['Lo-fi', 'Indie'],
    },
  },
  {
    id: 'hannah', name: 'Hannah', age: 30, gender: 'Woman', cherry: 'girl', city: 'Dublin, Ireland', lookingFor: 'friends',
    photo: { emoji: '🥧', colors: ['#FFF1C1', '#F6BD60'] },
    food: {
      cookingRelationship: 'I love cooking and do it almost every day', foodType: 'I eat pretty much everything', restrictions: [],
      cuisines: ['British', 'French', 'Middle Eastern', 'Italian'], topCuisines: ['British', 'French', 'Middle Eastern'],
      signatureDish: 'Apple and blackberry pie', comfortFood: 'Shepherd’s pie', adventure: 5,
      idealDate: 'Baking something sweet', cookingPersonality: ['The organised chef'],
      cookingTime: 'I could spend the whole evening cooking', musicGenres: ['Classical', 'Indie'],
    },
  },
  {
    id: 'sam', name: 'Sam', age: 27, gender: 'Man', cherry: 'boy', city: 'Glasgow, UK', lookingFor: 'friends',
    photo: { emoji: '🍜', colors: ['#E2ECE9', '#8FC1B5'] },
    food: {
      cookingRelationship: 'I mostly survive on takeaways', foodType: 'Non-vegetarian', restrictions: [],
      cuisines: ['Chinese', 'Japanese', 'Mexican', 'Thai'], topCuisines: ['Chinese', 'Japanese', 'Thai'],
      signatureDish: 'Midnight ramen with a jammy egg', comfortFood: 'Chicken chow mein', adventure: 6,
      idealDate: "Honestly, I'd rather eat than cook", cookingPersonality: ['The food critic', 'The lazy chef'],
      cookingTime: '15 minutes or less', musicGenres: ['Rock', 'Hip-hop'],
    },
  },
];

export const crowd = crowdProfiles.map((p) => ({ ...p, email: `${p.id}@bakeout.demo` }));

export const everyone = [...readyMade, ...crowd];
