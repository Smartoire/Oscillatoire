# Evidence behind the scores

What the research says about the signals Brainwave shows, and what that means for how the app
should describe them. This is a short literature check from abstracts and snippets, not a full
systematic review. Check the sources before you rely on any detail.

Brainwave shows trends relative to your own baseline. It doesn't measure emotions, stress or
health, and it isn't for research or clinical use.

## Focus (β ÷ (α + θ))

- Pope, Bogart and Bartolome (1995) reported that β ÷ (α + θ) tracked task engagement best among the
  candidate indices they tested, judged by closed-loop control behaviour, not by checking against an
  independent measure of engagement.
  Source: [Biocybernetic system evaluates indices of operator engagement](https://ntrs.nasa.gov/citations/19970003078)
- Later work notes that the index depends on how the bands are defined, so values from different
  apps and studies aren't directly comparable.

**For the app:** keep "Focus" as an estimate. Scores are relative to you, not absolute.

## Calm (α ÷ β) and "Stressed"

- Alpha power rising during meditation is the most consistent EEG finding. A systematic review of
  EEG in mindfulness (56 studies, 1,715 participants) found increased alpha and theta, and no consistent
  pattern for beta, delta or gamma. It did not report a beta-to-alpha ratio as an outcome.
  Source: [Lomas, Ivtzan and Fu (2015), via the search results](https://pmc.ncbi.nlm.nih.gov/articles/PMC4684838)
- The β ÷ α ratio as a stress marker has theoretical support, but I found little meditation-specific
  systematic evidence. Where it appears, it comes from non-peer-reviewed theses.

**For the app:** "Calm" is the better-supported label. Present "Stressed" as the low end of the same
scale, and say that it's tentative. The calm session's sound and count should be described as a
relaxation aid, not a stress measurement. On Android the calm sound is one soft scale per breath,
which is a rhythm cue, not a measure of calm.

## Frontal asymmetry (left vs right comparison)

- Davidson's approach-withdrawal account links left frontal activity with approach and right frontal
  activity with withdrawal. The idea is widely used, but results are mixed, especially for clinical and
  event-related use. A 2019 meta-analysis found replicability unclear for personality links.
  Sources: [Sabu et al. (2022) review](https://publications.tno.nl/publication/34639710/Ct4x8B/sabu-2022-review.pdf),
  [Resting frontal EEG asymmetry and personality traits](https://ouci.dntb.gov.ua/works/4N5BaoV7)

**For the app:** the comparison sentences say which side is "more active". They shouldn't imply
approach or withdrawal, emotion or mood.

## Muse accuracy

- A 2024 comparison of consumer dry-electrode headsets found that Muse S Gen 2 gave the weakest
  agreement with a research amplifier among the devices tested. Muse's flat electrodes were suggested as
  one reason.
  Source: [Sensors, Dec 2024, consumer vs research-grade devices](https://www.mdpi.com/1424-8220/24/24/8108)
- A 2024 Frontiers study comparing Muse with a gel-based system reported limitations in signal quality,
  while noting that Muse has been used for ERP research.
  Source: [Frontiers in Neuroscience (2024)](https://www.frontiersin.org/articles/10.3389/fnins.2024.1326139)
- A 2021 bioRxiv preprint said Muse had not yet been validated for frequency-domain analysis, such as
  power spectra and frontal alpha asymmetry.
  Source: [bioRxiv (2021)](https://www.biorxiv.org/content/biorxiv/early/2021/11/04/2021.11.02.466989.full.pdf)

**For the app:** keep calling the scores trends, not measurements, and say so in the Mind tab and Info.
Consider a note in the README that absolute band power varies with the device and the person.

## Movement and artefacts

- Wearable EEG artefacts behave differently from lab EEG: dry electrodes, fewer channels and movement
  all matter. A 2025 systematic review (58 studies) found few that address these artefacts, and only two
  that identify artefact categories such as eye versus muscle.
  Source: [Systematic review of artefact detection in wearable EEG (PMC12473706)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12473706/)
- Dry electrodes are more sensitive to motion than gel electrodes.
  Source: [Frontiers in Neuroscience (2021) editorial](https://www.frontiersin.org/journals/neuroscience/articles/10.3389/fnins.2021.809227/epub)

**For the app:** the movement warning is a simple accelerometer threshold (0.15 g). It doesn't reject
blinks or muscle activity, so the scores can still move with them. Tune the threshold on real recordings
before relying on it.

## Summary of what to tell users

- The scores are trends against your own usual level.
- Movement, blinks, poor contact and the headband itself all affect the readings.
- Calm, focus and sleepiness are estimates from brainwave ratios. They aren't medical measurements.
