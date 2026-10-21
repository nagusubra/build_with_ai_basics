import type { Firestore } from 'firebase-admin/firestore';

/** The food-profile fields Cherry reasons with (`spec.md > Data Model`). */
export interface FoodProfile {
  cookingRelationship?: string;
  foodType?: string;
  restrictions?: string[];
  cuisines?: string[];
  topCuisines?: string[];
  signatureDish?: string;
  adventure?: number;
  idealDate?: string;
  cookingPersonality?: string[];
  comfortFood?: string;
  cookingTime?: string;
  musicGenres?: string[];
  favouriteSong?: string;
}

export interface Person {
  uid: string;
  name: string;
  city?: string;
  food: FoodProfile;
}

export async function loadPeople(db: Firestore, uids: string[]): Promise<Person[]> {
  const docs = await Promise.all(uids.map((uid) => db.doc(`users/${uid}`).get()));
  return docs.map((d, i) => {
    const data = d.data() ?? {};
    return { uid: uids[i], name: (data.name as string) ?? 'Someone', city: data.city as string | undefined, food: (data.food ?? {}) as FoodProfile };
  });
}

const lower = (xs?: string[]) => new Set((xs ?? []).map((x) => x.toLowerCase()));
const shared = (a?: string[], b?: string[]) => [...lower(a)].filter((x) => lower(b).has(x));

/** Real overlaps between two food profiles, most specific first, in plain words. */
export function commonGround(a: FoodProfile, b: FoodProfile): string[] {
  const out: string[] = [];
  const top = shared(a.topCuisines, b.topCuisines);
  if (top.length) out.push(`both have ${top.join(' and ')} food in their top three`);
  const cuisines = shared(a.cuisines, b.cuisines).filter((c) => !top.includes(c));
  if (cuisines.length) out.push(`both love ${cuisines.slice(0, 2).join(' and ')} food`);
  if (a.foodType && a.foodType === b.foodType) out.push(`both are ${a.foodType}`);
  if (a.idealDate && a.idealDate === b.idealDate) out.push(`both picked "${a.idealDate}" as their ideal cooking date`);
  const styles = shared(a.cookingPersonality, b.cookingPersonality);
  if (styles.length) out.push(`both call themselves ${styles[0]}`);
  if (a.cookingTime && a.cookingTime === b.cookingTime) out.push(`both like cooking for ${a.cookingTime}`);
  const music = shared(a.musicGenres, b.musicGenres);
  if (music.length) out.push(`both cook to ${music.join(' and ')}`);
  return out;
}

/** A compact profile summary for prompts; only fields the person actually filled in. */
export function describe(p: Person): string {
  const f = p.food;
  const lines = [
    `Name: ${p.name}`,
    f.cookingRelationship && `Relationship with cooking: ${f.cookingRelationship}`,
    f.foodType && `Food type: ${f.foodType}`,
    f.restrictions?.length && `Dietary restrictions/allergies: ${f.restrictions.join(', ')}`,
    f.topCuisines?.length && `Top cuisines: ${f.topCuisines.join(', ')}`,
    f.cuisines?.length && `Cuisines they enjoy: ${f.cuisines.join(', ')}`,
    f.signatureDish && `Signature dish: ${f.signatureDish}`,
    f.comfortFood && `Comfort food: ${f.comfortFood}`,
    f.adventure !== undefined && `Food adventure level: ${f.adventure}/10`,
    f.idealDate && `Ideal cooking date: ${f.idealDate}`,
    f.cookingPersonality?.length && `Cooking personality: ${f.cookingPersonality.join(', ')}`,
    f.cookingTime && `Happy cooking time: ${f.cookingTime}`,
    f.musicGenres?.length && `Cooks to: ${f.musicGenres.join(', ')}`,
    f.favouriteSong && `Favourite cooking song: ${f.favouriteSong}`,
  ];
  return lines.filter(Boolean).join('\n');
}
