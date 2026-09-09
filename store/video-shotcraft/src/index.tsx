import React from 'react';
import {registerRoot, Composition} from 'remotion';
import {Promo} from './Promo';
import {FPS, TOTAL} from './timeline.mjs';
registerRoot(() => <Composition id="Shotcraft" component={Promo} width={1920} height={1080} fps={FPS} durationInFrames={TOTAL}/>);
