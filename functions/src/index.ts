import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';

initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

export { cherryDecide } from './cherry/decide';
export { cherryOpening } from './cherry/opening';
export { confirmDatePlan, dismissCherry } from './cherry/plan';
export { cherryTick } from './cherry/tick';
