/* Ruxtape */
$(document).ready(function(){
    $("#warning").hide(); // shows a warning if javascript isn't enabled
});

/* Player Config */

soundManager.url = '../../assets/soundmanager';

var PP_CONFIG = {
  flashVersion: 9,       // version of Flash to tell SoundManager to use - either 8 or 9. Flash 9 required for peak / spectrum data.
  usePeakData: true,     // [Flash 9 only] whether or not to show peak data (left/right channel values) - nor noticable on CPU
  useWaveformData: false, // [Flash 9 only] show raw waveform data - WARNING: LIKELY VERY CPU-HEAVY
  useEQData: false ,      // [Flash 9 only] show EQ (frequency spectrum) data  - Perfomance has been varied for me.
  useFavIcon: false       // try to apply peakData to address bar (Firefox + Opera) - performance note: appears to make Firefox 3 do some temporary, heavy disk access/swapping/garbage collection at first(?)
}
