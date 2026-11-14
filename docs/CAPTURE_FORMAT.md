# Capture export format

A capture is a recorded window of Muse activity. Brainwave exports it two ways: from the capture's
share button (both files together), or with **Download** when a recording stops. The **CSV** file is for
spreadsheets, and the **JSON** file is for analysis tools and agents. Both come from the same data. A JSON
file can be imported back into the Captures tab with **Import** on iPhone and Mac. The Android Captures
page shows the saved list only for now, so import is not available there yet.

Brainwave is free, open-source and for personal, educational use. The exports are not
medical data and must not be used for diagnosis, treatment or research decisions.

## CSV (spreadsheets)

One row per second. Empty cells mean no reading at that moment.

| Column | Meaning |
|---|---|
| `time_s` | Seconds since the capture started. |
| `power_<band>_<sensor>` | Band power, log10 µV². Bands: `delta`, `theta`, `alpha`, `beta`, `gamma`. Sensors: `tp9`, `af7`, `af8`, `tp10`. |
| `activation_<band>_<sensor>` | How far that band's power is from your own usual level, in standard deviations. Positive means more than usual. |
| `score_focus`, `score_calm`, `score_sleepiness` | Scores from 0 to 100. 50 is your usual level. Calm falls to "stressed" at the low end. |
| `contact_<sensor>` | Contact quality for that sensor: `good`, `ok`, `bad`, or empty if none. |
| `movement_g` | How far the headband's acceleration is from gravity, in g. Above about 0.15 the readings are less reliable. |

The file starts with a header row. The file name is the capture's start time.

## JSON (analysis tools and agents)

Top level:

```json
{
  "format": "brainwave.capture",
  "version": 1,
  "capture": {
    "id": "UUID",
    "started": "ISO 8601 date and time",
    "device": "Headband name, or Demo headband",
    "duration": 120.0,
    "samples": [ ... ]
  }
}
```

Each sample:

- `time`: seconds since the start.
- `power`: 20 values, band by sensor. Index = `band * 4 + sensor`, where bands are
  `delta, theta, alpha, beta, gamma` (0 to 4) and sensors are `tp9, af7, af8, tp10` (0 to 3).
- `activation`: 20 values in the same layout, as z-scores against your own baseline.
- `scores`: 3 values, in the order focus, calm, sleepiness. 0 to 100.
- `contact`: 4 values in sensor order: `good`, `ok`, `bad`, or `null`.
- `movement`: a number in g, or `null`.

`null` means there was no reading. Activation is the most useful value for comparing areas:
average the sensors that cover an area, as the Compare screen does.

## Notes for analysis

- Scores and activation are relative to each person's own recent baseline, so compare
  within one person's captures, not across people.
- Calm and stress come from the same signal, so the calm score is high when you are settled
  and low when you are tense.
- The headband's readings are affected by blinking, head movement and poor contact. Check
  `contact` and `movement` before reading much into a stretch of data.
