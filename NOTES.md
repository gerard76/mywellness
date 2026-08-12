# Notes

Hard-won details about the Mywellness/Technogym API and this dataset. Read before
touching the sync or writing analysis queries.

## The platform moved

`v1.mywellness.com` is retired and 302s every path to `www.technogym.com`. The old
export-based scraper (generate export → poll → download zip) cannot work and has been
deleted. The manual upload at `/uploads/new` still accepts the old zip/JSON format, so
a GDPR data request from Technogym remains a usable import path.

The current web app at `endusernext.mywellness.com` only covers home, calendar and
account. It has no training history, so the phone app is the only client that reads
workout data.

## API

Auth, then two calls for workouts and one for body metrics:

```
POST core.mywellness.com/v2/enduser/authentication/login
     {username, password, keepMeLoggedIn}  ->  {token, userContext.id, facilities[]}

     All later calls need:
       Authorization: Bearer <token>
       X-MWAPPS-APPID / -CLIENT / -CLIENTVERSION / -FACILITYID

GET  workout.mywellness.com/logbook?from=YYYYMMDD&to=YYYYMMDD
     -> data.logbooks[]; entries with type=="GenericWorkout" carry idCr

GET  workout.mywellness.com/logbook/workout/{idCr}
     -> data.exercises[], data.exerciseGroups[], startedOn, closedOn

POST services.mywellness.com/Biometrics/User/{userId}/LastBiometricsMeasurements
     -> data.lastMeasurements[]
```

Other live hosts seen from the app: `cms`, `calendar`, `challenges`, `coach`,
`messenger`, `pay`, `iotcore`. The documented partner API on `apidocs.mywellness.com`
is a different thing entirely: it needs a ClientId from Technogym and its logbook
endpoint returns prose ("You completed a workout of 2 exercises"), not measurements.

`hrSamples` and `hrZones` exist on the workout but are empty — no heart rate monitor
is paired. If one is ever paired, heart rate arrives through the call we already make.

## Traps in the workout payload

**Two different things are called Rm1.** `userReferenceValues["Rm1"]` is the one-rep max
stored on the profile from the last max test — identical on every set and every day
until retested. Importing it flatlines every chart. The old export instead held a
per-set estimate, reproduced exactly by Epley:

```ruby
reps = TotalIsoWeight / IsoWeight   # 10 in practice
rm1  = IsoWeight * (1 + reps / 30)
```

Verified against all 14 machines on 2026-07-23, the last day the old export covered.

**A workout lists the whole programme, including skipped exercises.** Rm1 is present
either way, so `doneProperties` is the only proof a set happened. Without that check
the importer invents sessions — it did, for a machine that was out of order.

**Positions are per-workout, not fixed.** `exerciseGroups` defines the circuits and
which positions belong to which round. Circuit order varies between sessions, so
hardcoding position ranges silently mislabels everything. Always read the groups.

**Biometric names are localised** ("Vetmassa" with `_c=nl-NL`). Map on the language
independent `type`, e.g. `UserWeight`, `FatMassPercentace` (their spelling).

`physicalActivityId` in the API is the same value as `phId` in the old export, which is
what let the two eras line up on `machines.ph_id`.

## Dataset quirks

- **2026-03-02 was a one-rep max test**, not a normal session. Values run 2.3–4.5x a
  normal day. Real data, kept in the database, excluded from the charts via
  `HomeController::MAX_TEST_DATES`. Add a date there if another test happens.
- A double import in March left 75 duplicate rows. Removed, and
  `(machine_id, workout_date)` is now a unique index.
- Five machine names were shifted by one against the circuit order and have been
  corrected. Technogym's names differ but mean the same machine: Vertical Traction =
  Pull Down, Total Abdominal = Crunch, Pectoral = Arm Adduction, Abductor/Adductor =
  Hip Abduction/Adduction.

## Analysis traps

Mistakes made while reading this data, all of which produced confident wrong answers:

- **Programme size varies.** March–June mixes 12, 18, 23, 30, 31, 34, 44 and 48-set
  sessions; only July onward is consistently 30. Comparing "average sets done" across
  months compares different programmes. Filter to one size first.
- **Average weight is computed over completed sets only.** Skipping the heavy machines
  drags the average down, so a low average can mean a harder session, not an easier one.
- **Completion rate and sets-done tell opposite stories.** Sets done held steady while
  the share of fully completed sessions fell from 76% to ~30%. Track completion.
- Check whether a suspected driver actually varies before believing it. Training
  frequency looked like the cause of a decline until the data showed it had been
  constant for five months.

## The circuit

Two fixed circuits, two rounds each, 30s rest between machines. The trainee sets the
weights himself ("progressie uit" means manual progression, not disabled progression)
and can only choose the order of the circuits and the pause between them.

```
circuit of 6:  Arm Curl, Pectoral, Arm Extension, Vertical Traction, Abductor, Adductor
circuit of 9:  Leg Extension, Leg Press, Lower Back, Chest Press, Shoulder Press,
               Vertical Traction, Leg Curl, Low Row, Total Abdominal
```

Vertical Traction sits in both, so it gets 4 sets a session where everything else gets
2 — which makes it the most-skipped machine despite a modest weight, and means its
stored weight cannot be tuned per circuit.

Findings that held up: dropouts are almost entirely in round 2 (100 of 112 missed sets),
and starting with the circuit of 9 completes 44% of the time against 11% starting with
the circuit of 6, measured within one month so the load is comparable.
