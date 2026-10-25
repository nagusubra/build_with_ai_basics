// Run through Playwright's code-file tool on either rig's standalone preview.
async (page) => {
  await page.bringToFront();
  const config = await page.evaluate(() => {
    if (document.hidden) throw new Error('Preview tab must be visible for real-time playback QA');
    return {boards: BOARDS, jill: BOARDS[0] === 'JillWingwoman'};
  });
  const folder = config.jill ? 'mascot_rive_jill' : 'mascot_rive_jack';
  const durations = [8, 2.5, 2, 3, 2];
  const reports = [];
  for (const [index, board] of config.boards.entries()) {
    await page.evaluate(board => play(board), board);
    await page.waitForFunction(() => players.length === 2 && players.every(player => player.loaded),
      undefined, {timeout: 20000});
    await page.evaluate(() => {
      window.__playback = {frames: 0, seconds: 0, maxDelta: 0};
      players[0].on(rive.EventType.Advance, event => {
        __playback.frames++;
        __playback.seconds += event.data;
        __playback.maxDelta = Math.max(__playback.maxDelta, event.data);
      });
    });
    await page.waitForTimeout(400);
    const first = await page.evaluate(() => document.getElementById('big').toDataURL());
    await page.waitForTimeout(700);
    const changed = await page.evaluate(first => document.getElementById('big').toDataURL() !== first, first);
    if (!changed) throw new Error(board + ' canvas did not change during playback');
    await page.waitForFunction(seconds => __playback.seconds >= seconds, durations[index] * 3 + 0.1,
      {timeout: 35000, polling: 100});
    const report = await page.evaluate(board => ({
      artboard: board, ...__playback,
      players: players.map(player => ({loaded: player.loaded, playing: player.isPlaying,
        stateMachine: player.playingStateMachineNames[0]})),
      error: document.getElementById('err').textContent,
    }), board);
    if (report.error || report.players.some(player => !player.loaded || !player.playing || player.stateMachine !== board))
      throw new Error(JSON.stringify(report));
    reports.push(report);
    await page.screenshot({path: `app\\tool\\${folder}\\build\\browser_${board}.png`});
    if (index === 0)
      await page.screenshot({path: `app\\tool\\${folder}\\build\\browser_review.png`});
  }
  await page.evaluate(reports => { window.__browserQa = reports; }, reports);
  return reports;
}
