import { GoogleGenAI, ThinkingLevel } from '@google/genai';
import { defineSecret } from 'firebase-functions/params';

import { GEMINI_MODEL } from './config';

/** Paid-tier key: `firebase functions:secrets:set GEMINI_API_KEY`; emulator reads `functions/.secret.local`. */
export const geminiKey = defineSecret('GEMINI_API_KEY');

const clients = new Map<string, GoogleGenAI>();

/** Asks Gemini for JSON matching `schema` and parses it. Throws on empty or invalid output. */
export async function askJson<T>(opts: { apiKey: string; system: string; prompt: string; schema: object }): Promise<T> {
  let ai = clients.get(opts.apiKey);
  if (!ai) {
    ai = new GoogleGenAI({ apiKey: opts.apiKey });
    clients.set(opts.apiKey, ai);
  }
  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: opts.prompt,
    config: {
      systemInstruction: opts.system,
      responseMimeType: 'application/json',
      responseJsonSchema: opts.schema,
      thinkingConfig: { thinkingLevel: ThinkingLevel.LOW },
    },
  });
  const text = response.text;
  if (!text) throw new Error('Gemini returned no text');
  return JSON.parse(text) as T;
}
