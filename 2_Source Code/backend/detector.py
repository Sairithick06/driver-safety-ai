import cv2
import mediapipe as mp
import math
import time
from collections import deque
import numpy as np


# ============================================================
# DRIVER SAFETY AI - CORE DETECTION ENGINE
# ============================================================
# Flow:
# FRAME -> MEASUREMENT -> STATE -> EVENT -> BEHAVIOR ->
# FATIGUE -> SAFETY -> SESSION/API
#
# This module owns AI detection only. Notification delivery and
# escalation are handled by the Flutter alert module.
# ============================================================


# ============================================================
# MEDIAPIPE FACE MESH
# ============================================================

mp_face_mesh = mp.solutions.face_mesh

face_mesh = mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5,
)


# ============================================================
# FACE LANDMARKS
# ============================================================

LEFT_EYE = {
    "left": 33,
    "right": 133,
    "upper1": 160,
    "lower1": 144,
    "upper2": 158,
    "lower2": 153,
}

RIGHT_EYE = {
    "left": 362,
    "right": 263,
    "upper1": 385,
    "lower1": 380,
    "upper2": 387,
    "lower2": 373,
}

UPPER_LIP = 13
LOWER_LIP = 14
LEFT_MOUTH = 78
RIGHT_MOUTH = 308

NOSE_TIP = 1
CHIN = 152
LEFT_EYE_CORNER = 33
RIGHT_EYE_CORNER = 263
LEFT_MOUTH_CORNER = 61
RIGHT_MOUTH_CORNER = 291


# ============================================================
# CALIBRATION
# ============================================================

CALIBRATION_FRAMES = 30
CALIBRATION_OPEN_FLOOR = 0.20

calibration_values_left = []
calibration_values_right = []
calibration_complete = False
left_baseline_ear = None
right_baseline_ear = None


# ============================================================
# DEFAULT EAR THRESHOLDS
# ============================================================

DEFAULT_LEFT_CLOSE = 0.24
DEFAULT_LEFT_OPEN = 0.30
DEFAULT_RIGHT_CLOSE = 0.24
DEFAULT_RIGHT_OPEN = 0.30

LEFT_CLOSE = DEFAULT_LEFT_CLOSE
LEFT_OPEN = DEFAULT_LEFT_OPEN
RIGHT_CLOSE = DEFAULT_RIGHT_CLOSE
RIGHT_OPEN = DEFAULT_RIGHT_OPEN


# ============================================================
# EYE SETTINGS
# ============================================================

EYE_CLOSE_RATIO = 0.68
EYE_OPEN_RATIO = 0.78

# A second, slightly wider band is used only for smoothed/transition
# measurements. Raw calibrated EAR remains the fastest signal for a real
# eye opening/closing change.
EYE_SMOOTH_CLOSE_RATIO = 0.70
EYE_SMOOTH_OPEN_RATIO = 0.80

# Consecutive-frame confirmation prevents one noisy landmark frame from
# changing the eye state, while still allowing a genuine expression change
# to propagate quickly.
EYE_STATE_CONFIRM_FRAMES = 2

MIN_BLINK_DURATION = 0.05
MAX_BLINK_DURATION = 1.20
LONG_CLOSURE_DURATION = 2.00

# A short landmark failure does not immediately destroy a valid state.
# After this time, the product state becomes "Waiting for Driver".
EYE_INVALID_GRACE_SECONDS = 0.75

# The two eyes may close/reopen a small amount apart and still count as
# one normal binocular blink.
BLINK_PAIR_WINDOW_SECONDS = 0.35


# ============================================================
# YAWN SETTINGS
# ============================================================

YAWN_THRESHOLD = 0.45
YAWN_RELEASE_THRESHOLD = 0.34
YAWN_HARD_RELEASE_THRESHOLD = 0.28
YAWN_CONFIRM_SECONDS = 0.45
YAWN_MIN_DURATION = 0.60
YAWN_RELEASE_SECONDS = 0.12
YAWN_COOLDOWN_SECONDS = 3.00
YAWN_HISTORY_SECONDS = 60.0


# ============================================================
# HEAD SETTINGS
# ============================================================

YAW_THRESHOLD = 15.0
PITCH_THRESHOLD = 15.0
HEAD_EXIT_YAW_THRESHOLD = 8.0
HEAD_EXIT_PITCH_THRESHOLD = 8.0
HEAD_HISTORY_SIZE = 2
HEAD_AWAY_CONFIRM_SECONDS = 1.0

# Reject obviously unstable pose solutions rather than showing a
# misleading extreme direction.
MAX_VALID_HEAD_ANGLE = 75.0


# ============================================================
# FACE VISIBILITY / SAFETY SETTINGS
# ============================================================

# The detector exposes this duration to the alert module. At 3 minutes
# the alert module can escalate the active face-not-visible incident to
# the emergency-contact call workflow.
FACE_NOT_DETECTED_ESCALATION_SECONDS = 180.0

# A brief missed frame is tolerated before an active face-dependent state
# is cleared. This is time based, not frame-count based.
FACE_MISSING_STATE_RESET_SECONDS = 0.75


# ============================================================
# LOW-LIGHT SETTINGS
# ============================================================

LOW_LIGHT_MEAN_THRESHOLD = 70.0
LOW_LIGHT_GAMMA = 1.45
CLAHE_CLIP_LIMIT = 2.0
CLAHE_TILE_GRID = (8, 8)


# ============================================================
# SMOOTHING
# ============================================================

EAR_HISTORY_SIZE = 2
MOUTH_HISTORY_SIZE = 3

left_ear_history = deque(maxlen=EAR_HISTORY_SIZE)
right_ear_history = deque(maxlen=EAR_HISTORY_SIZE)
mouth_mar_history = deque(maxlen=MOUTH_HISTORY_SIZE)

pitch_history = deque(maxlen=HEAD_HISTORY_SIZE)
yaw_history = deque(maxlen=HEAD_HISTORY_SIZE)
roll_history = deque(maxlen=HEAD_HISTORY_SIZE)


# ============================================================
# EVENT HISTORY
# ============================================================

blink_timestamps = deque()
yawn_timestamps = deque()


# ============================================================
# EYE STATE
# ============================================================

# None is used internally for a measurement that is currently unavailable.
# No technical UNKNOWN value is exposed through the product API.
left_eye_state = None
right_eye_state = None
combined_eye_state = None

left_eye_previous_valid = None
right_eye_previous_valid = None

left_eye_invalid_since = None
right_eye_invalid_since = None

left_closed_start = None
right_closed_start = None
left_closed_duration = 0.0
right_closed_duration = 0.0

# Used to pair the two eyes into one blink event.
left_reopen_pending = None
right_reopen_pending = None
left_reopen_duration = None
right_reopen_duration = None

blink_count = 0


# ============================================================
# YAWN STATE
# ============================================================

yawning_active = False
yawning_start_time = None
yawning_clear_start_time = None
last_yawn_event_time = None
yawn_count = 0


# ============================================================
# HEAD STATE
# ============================================================

head_position = "Face Not Visible"
head_away_start = None
last_valid_head_position = "Looking Straight"


# ============================================================
# FACE VISIBILITY STATE
# ============================================================

face_missing_start = None
face_missing_duration = 0.0
face_missing_event_active = False
face_missing_event_count = 0


# ============================================================
# SESSION STATISTICS
# ============================================================

monitoring_session_started_at = None
last_detection_time = None

max_closed_duration = 0.0
max_face_missing_duration = 0.0

total_analysis_frames = 0

fatigue_period_active = False
fatigue_period_count = 0
warning_period_active = False
warning_period_count = 0
danger_period_active = False
danger_period_count = 0


# ============================================================
# UTILITY
# ============================================================

def euclidean(p1, p2):
    return math.sqrt(
        (p1.x - p2.x) ** 2 +
        (p1.y - p2.y) ** 2
    )


def safe_float(value, default=0.0):
    try:
        value = float(value)
        if math.isfinite(value):
            return value
    except (TypeError, ValueError):
        pass
    return default


def median_or_zero(values):
    if not values:
        return 0.0
    return float(np.median(np.asarray(values, dtype=np.float64)))


# ============================================================
# LOW-LIGHT PREPROCESSING
# ============================================================

def preprocess_frame_for_detection(frame):
    if frame is None or frame.size == 0:
        return frame, False, 0.0

    try:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        mean_brightness = float(np.mean(gray))
    except Exception:
        return frame, False, 0.0

    if mean_brightness >= LOW_LIGHT_MEAN_THRESHOLD:
        return frame, False, mean_brightness

    gamma = LOW_LIGHT_GAMMA
    inverse_gamma = 1.0 / gamma

    table = np.array(
        [
            ((i / 255.0) ** inverse_gamma) * 255.0
            for i in np.arange(256)
        ],
        dtype=np.uint8,
    )

    enhanced = cv2.LUT(frame, table)

    lab = cv2.cvtColor(enhanced, cv2.COLOR_BGR2LAB)
    l_channel, a_channel, b_channel = cv2.split(lab)

    clahe = cv2.createCLAHE(
        clipLimit=CLAHE_CLIP_LIMIT,
        tileGridSize=CLAHE_TILE_GRID,
    )
    l_channel = clahe.apply(l_channel)

    enhanced = cv2.cvtColor(
        cv2.merge((l_channel, a_channel, b_channel)),
        cv2.COLOR_LAB2BGR,
    )

    return enhanced, True, mean_brightness


# ============================================================
# RAW MEASUREMENTS
# ============================================================

def eye_aspect_ratio(landmarks, eye):
    try:
        left = landmarks[eye["left"]]
        right = landmarks[eye["right"]]
        upper1 = landmarks[eye["upper1"]]
        lower1 = landmarks[eye["lower1"]]
        upper2 = landmarks[eye["upper2"]]
        lower2 = landmarks[eye["lower2"]]

        horizontal = euclidean(left, right)
        if horizontal < 1e-6:
            return None

        vertical1 = euclidean(upper1, lower1)
        vertical2 = euclidean(upper2, lower2)

        ear = (vertical1 + vertical2) / (2.0 * horizontal)

        if not math.isfinite(ear) or ear <= 0.0:
            return None

        return float(ear)
    except (IndexError, AttributeError, TypeError, ValueError):
        return None


def mouth_open(landmarks):
    try:
        upper = landmarks[UPPER_LIP]
        lower = landmarks[LOWER_LIP]
        left = landmarks[LEFT_MOUTH]
        right = landmarks[RIGHT_MOUTH]

        vertical = euclidean(upper, lower)
        horizontal = euclidean(left, right)

        if horizontal < 1e-6:
            return None

        mar = vertical / horizontal

        if not math.isfinite(mar) or mar < 0.0:
            return None

        return float(mar)
    except (IndexError, AttributeError, TypeError, ValueError):
        return None


# ============================================================
# RATE CALCULATIONS
# ============================================================

def get_blink_rate():
    current_time = time.time()

    while blink_timestamps:
        if current_time - blink_timestamps[0] > 60.0:
            blink_timestamps.popleft()
        else:
            break

    return len(blink_timestamps)


def get_yawn_rate():
    current_time = time.time()

    while yawn_timestamps:
        if current_time - yawn_timestamps[0] > YAWN_HISTORY_SECONDS:
            yawn_timestamps.popleft()
        else:
            break

    return len(yawn_timestamps)


# ============================================================
# RESET FUNCTIONS
# ============================================================

def reset_eye_state():
    global left_eye_state
    global right_eye_state
    global combined_eye_state
    global left_eye_previous_valid
    global right_eye_previous_valid
    global left_eye_invalid_since
    global right_eye_invalid_since
    global left_closed_start
    global right_closed_start
    global left_closed_duration
    global right_closed_duration
    global left_reopen_pending
    global right_reopen_pending
    global left_reopen_duration
    global right_reopen_duration

    left_eye_state = None
    right_eye_state = None
    combined_eye_state = None

    left_eye_previous_valid = None
    right_eye_previous_valid = None

    left_eye_invalid_since = None
    right_eye_invalid_since = None

    left_closed_start = None
    right_closed_start = None
    left_closed_duration = 0.0
    right_closed_duration = 0.0

    left_reopen_pending = None
    right_reopen_pending = None
    left_reopen_duration = None
    right_reopen_duration = None


def reset_yawning_state():
    global yawning_active
    global yawning_start_time
    global yawning_clear_start_time
    global last_yawn_event_time

    yawning_active = False
    yawning_start_time = None
    yawning_clear_start_time = None
    last_yawn_event_time = None


def reset_head_state():
    global head_position
    global head_away_start
    global last_valid_head_position

    head_position = "Face Not Visible"
    head_away_start = None
    last_valid_head_position = "Looking Straight"

    pitch_history.clear()
    yaw_history.clear()
    roll_history.clear()


def reset_face_visibility_state():
    global face_missing_start
    global face_missing_duration
    global face_missing_event_active

    face_missing_start = None
    face_missing_duration = 0.0
    face_missing_event_active = False


def reset_monitoring():
    global blink_count
    global yawn_count
    global calibration_values_left
    global calibration_values_right
    global calibration_complete
    global left_baseline_ear
    global right_baseline_ear
    global LEFT_CLOSE
    global LEFT_OPEN
    global RIGHT_CLOSE
    global RIGHT_OPEN
    global monitoring_session_started_at
    global last_detection_time
    global max_closed_duration
    global max_face_missing_duration
    global fatigue_period_active
    global fatigue_period_count
    global warning_period_active
    global warning_period_count
    global danger_period_active
    global danger_period_count
    global total_analysis_frames
    global face_missing_event_count

    calibration_values_left = []
    calibration_values_right = []
    calibration_complete = False
    left_baseline_ear = None
    right_baseline_ear = None

    LEFT_CLOSE = DEFAULT_LEFT_CLOSE
    LEFT_OPEN = DEFAULT_LEFT_OPEN
    RIGHT_CLOSE = DEFAULT_RIGHT_CLOSE
    RIGHT_OPEN = DEFAULT_RIGHT_OPEN

    blink_count = 0
    yawn_count = 0
    blink_timestamps.clear()
    yawn_timestamps.clear()

    left_ear_history.clear()
    right_ear_history.clear()
    mouth_mar_history.clear()

    reset_eye_state()
    reset_yawning_state()
    reset_head_state()
    reset_face_visibility_state()

    monitoring_session_started_at = time.time()
    last_detection_time = monitoring_session_started_at

    max_closed_duration = 0.0
    max_face_missing_duration = 0.0
    face_missing_event_count = 0

    fatigue_period_active = False
    fatigue_period_count = 0
    warning_period_active = False
    warning_period_count = 0
    danger_period_active = False
    danger_period_count = 0
    total_analysis_frames = 0

    print("\n======================================")
    print("MONITORING RESET")
    print("Calibration restarted")
    print("Please keep your eyes OPEN")
    print("======================================\n")


# ============================================================
# EYE CALIBRATION
# ============================================================

def calibrate_eyes(left_ear, right_ear):
    global calibration_complete
    global left_baseline_ear
    global right_baseline_ear
    global LEFT_CLOSE
    global LEFT_OPEN
    global RIGHT_CLOSE
    global RIGHT_OPEN

    if calibration_complete:
        return

    if left_ear is None or right_ear is None:
        return

    if left_ear < CALIBRATION_OPEN_FLOOR or right_ear < CALIBRATION_OPEN_FLOOR:
        return

    calibration_values_left.append(float(left_ear))
    calibration_values_right.append(float(right_ear))

    frame_number = min(
        len(calibration_values_left),
        len(calibration_values_right),
    )

    if frame_number < CALIBRATION_FRAMES:
        return

    left_values = np.asarray(calibration_values_left, dtype=np.float64)
    right_values = np.asarray(calibration_values_right, dtype=np.float64)

    left_median = float(np.median(left_values))
    right_median = float(np.median(right_values))

    left_open_values = left_values[left_values >= left_median]
    right_open_values = right_values[right_values >= right_median]

    if len(left_open_values) == 0:
        left_open_values = left_values
    if len(right_open_values) == 0:
        right_open_values = right_values

    left_baseline_ear = float(np.median(left_open_values))
    right_baseline_ear = float(np.median(right_open_values))

    # Fixed-EAR fallbacks are deliberately derived from the driver's own
    # open-eye baseline.  The ratio classifier is used after calibration.
    LEFT_CLOSE = max(0.16, min(0.24, left_baseline_ear * 0.68))
    RIGHT_CLOSE = max(0.16, min(0.24, right_baseline_ear * 0.68))

    LEFT_OPEN = max(
        LEFT_CLOSE + 0.04,
        min(0.32, left_baseline_ear * 0.78),
    )
    RIGHT_OPEN = max(
        RIGHT_CLOSE + 0.04,
        min(0.32, right_baseline_ear * 0.78),
    )

    calibration_complete = True

    print("\n======================================")
    print("CALIBRATION COMPLETE")
    print("======================================")
    print(f"Left Baseline  : {left_baseline_ear:.3f}")
    print(f"Right Baseline : {right_baseline_ear:.3f}")
    print(f"Left Close     : {LEFT_CLOSE:.3f}")
    print(f"Left Open      : {LEFT_OPEN:.3f}")
    print(f"Right Close    : {RIGHT_CLOSE:.3f}")
    print(f"Right Open     : {RIGHT_OPEN:.3f}")
    print("======================================\n")


# ============================================================
# EYE STATE CLASSIFICATION
# ============================================================

def classify_eye(
    ear,
    baseline_ear,
    close_threshold,
    open_threshold,
    previous_state,
    invalid_since,
    current_time,
    smoothed_ear=None,
):
    """Classify one eye with fast raw response plus noise-resistant smoothing.

    The raw calibrated EAR ratio is deliberately checked first. This avoids
    the common failure where a median/EMA continues to report ``Closed`` for
    several frames after the driver has visibly opened the eye. Smoothed EAR
    is used only when the raw measurement is in the transition band.
    """
    if ear is None:
        if invalid_since is None:
            invalid_since = current_time

        if (
            previous_state in ("Open", "Closed")
            and current_time - invalid_since < EYE_INVALID_GRACE_SECONDS
        ):
            return previous_state, invalid_since

        return None, invalid_since

    invalid_since = None

    raw_ratio = None
    if baseline_ear is not None and baseline_ear > 0.0:
        raw_ratio = ear / baseline_ear

    # Strong current-frame evidence always wins.
    if raw_ratio is not None and math.isfinite(raw_ratio):
        if raw_ratio <= EYE_CLOSE_RATIO:
            return "Closed", None
        if raw_ratio >= EYE_OPEN_RATIO:
            return "Open", None

    # If the raw value is ambiguous, use the short smoothed history.
    if (
        smoothed_ear is not None
        and baseline_ear is not None
        and baseline_ear > 0.0
    ):
        smooth_ratio = smoothed_ear / baseline_ear
        if math.isfinite(smooth_ratio):
            if smooth_ratio <= EYE_SMOOTH_CLOSE_RATIO:
                return "Closed", None
            if smooth_ratio >= EYE_SMOOTH_OPEN_RATIO:
                return "Open", None

    # Final fallback for the transition zone. Prefer the current raw value
    # over freezing the old state, because the product must recover when the
    # driver changes expression.
    ratio = raw_ratio
    if ratio is not None and math.isfinite(ratio):
        midpoint = (EYE_CLOSE_RATIO + EYE_OPEN_RATIO) / 2.0
        return ("Open" if ratio >= midpoint else "Closed"), None

    # Calibration fallback.
    if ear <= close_threshold:
        return "Closed", None
    if ear >= open_threshold:
        return "Open", None

    midpoint = (close_threshold + open_threshold) / 2.0
    return ("Open" if ear >= midpoint else "Closed"), None


# ============================================================
# EYE CLOSURE TIMING
# ============================================================

def update_single_eye_closure(state, previous_state, closed_start, current_time):
    if state == "Closed":
        if previous_state != "Closed" or closed_start is None:
            closed_start = current_time
        return closed_start, max(0.0, current_time - closed_start)

    if state == "Open":
        return None, 0.0

    # Temporary measurement loss does not invent a new closure and does
    # not erase a real closure that was already in progress.
    if closed_start is not None:
        return closed_start, max(0.0, current_time - closed_start)

    return None, 0.0


# ============================================================
# COMBINED EYE STATE
# ============================================================

def combine_eye_states(left_state, right_state):
    if left_state == "Open" and right_state == "Open":
        return "Open"

    if left_state == "Closed" and right_state == "Closed":
        return "Closed"

    if left_state in ("Open", "Closed") and right_state in ("Open", "Closed"):
        return "One Eye Closed"

    return None


# ============================================================
# BLINK EVENT PROCESSING
# ============================================================

def process_blink(left_ear, right_ear, left_smoothed_ear=None, right_smoothed_ear=None):
    global blink_count
    global left_eye_state
    global right_eye_state
    global combined_eye_state
    global left_eye_previous_valid
    global right_eye_previous_valid
    global left_eye_invalid_since
    global right_eye_invalid_since
    global left_closed_start
    global right_closed_start
    global left_closed_duration
    global right_closed_duration
    global left_reopen_pending
    global right_reopen_pending
    global left_reopen_duration
    global right_reopen_duration
    global max_closed_duration

    current_time = time.time()

    previous_left = left_eye_state
    previous_right = right_eye_state

    previous_left_closed_start = left_closed_start
    previous_right_closed_start = right_closed_start

    left_eye_state, left_eye_invalid_since = classify_eye(
        left_ear,
        left_baseline_ear,
        LEFT_CLOSE,
        LEFT_OPEN,
        left_eye_previous_valid,
        left_eye_invalid_since,
        current_time,
        smoothed_ear=left_smoothed_ear,
    )

    right_eye_state, right_eye_invalid_since = classify_eye(
        right_ear,
        right_baseline_ear,
        RIGHT_CLOSE,
        RIGHT_OPEN,
        right_eye_previous_valid,
        right_eye_invalid_since,
        current_time,
        smoothed_ear=right_smoothed_ear,
    )

    if left_eye_state in ("Open", "Closed"):
        left_eye_previous_valid = left_eye_state
    if right_eye_state in ("Open", "Closed"):
        right_eye_previous_valid = right_eye_state

    left_closed_start, left_closed_duration = update_single_eye_closure(
        left_eye_state,
        previous_left,
        left_closed_start,
        current_time,
    )

    right_closed_start, right_closed_duration = update_single_eye_closure(
        right_eye_state,
        previous_right,
        right_closed_start,
        current_time,
    )

    # A blink begins when an eye closes. Reopening stores the completed
    # duration; the event is counted only when both eyes participate in
    # the same short closure window.
    left_reopened = previous_left == "Closed" and left_eye_state == "Open"
    right_reopened = previous_right == "Closed" and right_eye_state == "Open"

    if left_reopened:
        left_reopen_pending = current_time
        left_reopen_duration = (
            current_time - previous_left_closed_start
            if previous_left_closed_start is not None
            else None
        )

    if right_reopened:
        right_reopen_pending = current_time
        right_reopen_duration = (
            current_time - previous_right_closed_start
            if previous_right_closed_start is not None
            else None
        )

    # Pair two eye reopen events into exactly one blink.
    if left_reopen_pending is not None and right_reopen_pending is not None:
        if abs(left_reopen_pending - right_reopen_pending) <= BLINK_PAIR_WINDOW_SECONDS:
            left_duration_ok = (
                left_reopen_duration is not None
                and MIN_BLINK_DURATION <= left_reopen_duration <= MAX_BLINK_DURATION
            )
            right_duration_ok = (
                right_reopen_duration is not None
                and MIN_BLINK_DURATION <= right_reopen_duration <= MAX_BLINK_DURATION
            )

            if left_duration_ok or right_duration_ok:
                blink_count += 1
                blink_timestamps.append(current_time)

                print("\n======================================")
                print(f">>> BLINK DETECTED #{blink_count}")
                print(
                    f">>> Left Duration : "
                    f"{left_reopen_duration:.3f}s"
                    if left_reopen_duration is not None
                    else ">>> Left Duration : N/A"
                )
                print(
                    f">>> Right Duration: "
                    f"{right_reopen_duration:.3f}s"
                    if right_reopen_duration is not None
                    else ">>> Right Duration: N/A"
                )
                print("======================================\n")

            left_reopen_pending = None
            right_reopen_pending = None
            left_reopen_duration = None
            right_reopen_duration = None

    # Expire a half-pair. This prevents an isolated wink from being stored
    # forever while keeping independent eye states available to the UI.
    if (
        left_reopen_pending is not None
        and current_time - left_reopen_pending > BLINK_PAIR_WINDOW_SECONDS
    ):
        left_reopen_pending = None
        left_reopen_duration = None

    if (
        right_reopen_pending is not None
        and current_time - right_reopen_pending > BLINK_PAIR_WINDOW_SECONDS
    ):
        right_reopen_pending = None
        right_reopen_duration = None

    combined_eye_state = combine_eye_states(
        left_eye_state,
        right_eye_state,
    )

    active_closed_durations = [
        duration
        for duration in (left_closed_duration, right_closed_duration)
        if duration > 0.0
    ]

    if active_closed_durations:
        max_closed_duration = max(
            max_closed_duration,
            max(active_closed_durations),
        )

    # Safety-relevant prolonged closure is bilateral. A single closed eye
    # remains visible as "One Eye Closed" but does not become a dangerous
    # drowsiness closure by itself.
    if (
        left_eye_state == "Closed"
        and right_eye_state == "Closed"
    ):
        active_closed_duration = min(
            left_closed_duration,
            right_closed_duration,
        )
    else:
        active_closed_duration = 0.0

    return (
        left_eye_state,
        right_eye_state,
        combined_eye_state,
        active_closed_duration,
    )


# ============================================================
# HEAD POSE
# ============================================================

def estimate_head_pose(frame, landmarks):
    height, width = frame.shape[:2]

    try:
        image_points = np.array(
            [
                [landmarks[NOSE_TIP].x * width, landmarks[NOSE_TIP].y * height],
                [landmarks[CHIN].x * width, landmarks[CHIN].y * height],
                [landmarks[LEFT_EYE_CORNER].x * width, landmarks[LEFT_EYE_CORNER].y * height],
                [landmarks[RIGHT_EYE_CORNER].x * width, landmarks[RIGHT_EYE_CORNER].y * height],
                [landmarks[LEFT_MOUTH_CORNER].x * width, landmarks[LEFT_MOUTH_CORNER].y * height],
                [landmarks[RIGHT_MOUTH_CORNER].x * width, landmarks[RIGHT_MOUTH_CORNER].y * height],
            ],
            dtype=np.float64,
        )

        model_points = np.array(
            [
                [0.0, 0.0, 0.0],
                [0.0, -63.6, -12.5],
                [-43.3, 32.7, -26.0],
                [43.3, 32.7, -26.0],
                [-28.9, -28.9, -24.1],
                [28.9, -28.9, -24.1],
            ],
            dtype=np.float64,
        )

        focal_length = float(width)
        camera_matrix = np.array(
            [
                [focal_length, 0.0, width / 2.0],
                [0.0, focal_length, height / 2.0],
                [0.0, 0.0, 1.0],
            ],
            dtype=np.float64,
        )

        distortion_coefficients = np.zeros((4, 1), dtype=np.float64)

        success, rotation_vector, translation_vector = cv2.solvePnP(
            model_points,
            image_points,
            camera_matrix,
            distortion_coefficients,
            flags=cv2.SOLVEPNP_ITERATIVE,
        )

        if not success:
            return None, 0.0, 0.0, 0.0

        rotation_matrix, _ = cv2.Rodrigues(rotation_vector)
        pose_matrix = np.hstack((rotation_matrix, translation_vector))

        _, _, _, _, _, _, euler_angles = cv2.decomposeProjectionMatrix(
            pose_matrix
        )

        pitch = safe_float(euler_angles[0][0])
        yaw = safe_float(euler_angles[1][0])
        roll = safe_float(euler_angles[2][0])

        if pitch > 90.0:
            pitch -= 180.0
        elif pitch < -90.0:
            pitch += 180.0

        if yaw > 90.0:
            yaw -= 180.0
        elif yaw < -90.0:
            yaw += 180.0

        if roll > 90.0:
            roll -= 180.0
        elif roll < -90.0:
            roll += 180.0

        if (
            abs(pitch) > MAX_VALID_HEAD_ANGLE
            or abs(yaw) > MAX_VALID_HEAD_ANGLE
            or abs(roll) > MAX_VALID_HEAD_ANGLE
        ):
            return None, pitch, yaw, roll

        position = classify_head_position(pitch, yaw, roll, head_position)
        return position, pitch, yaw, roll

    except Exception as exc:
        print("Head pose error:", exc)
        return None, 0.0, 0.0, 0.0


def classify_head_position(pitch, yaw, roll, previous_position=None):
    abs_yaw = abs(yaw)
    abs_pitch = abs(pitch)

    # Do not let the previous direction lock the detector.  The current
    # measured pose always has priority; this is important when the driver
    # returns from looking down/left/right to the road.
    if abs_yaw < YAW_THRESHOLD and abs_pitch < PITCH_THRESHOLD:
        return "Looking Straight"

    if abs_yaw >= abs_pitch:
        return "Looking Right" if yaw > 0.0 else "Looking Left"

    return "Looking Up" if pitch > 0.0 else "Looking Down"


def stabilize_head_position(raw_position, pitch, yaw, roll):
    global head_position
    global head_away_start
    global last_valid_head_position

    current_time = time.time()

    if raw_position is None:
        return "Face Not Visible"

    pitch_history.append(pitch)
    yaw_history.append(yaw)
    roll_history.append(roll)

    smooth_pitch = median_or_zero(list(pitch_history))
    smooth_yaw = median_or_zero(list(yaw_history))
    smooth_roll = median_or_zero(list(roll_history))

    previous_position = last_valid_head_position

    stable_position = classify_head_position(
        smooth_pitch,
        smooth_yaw,
        smooth_roll,
        previous_position=previous_position,
    )

    # A clear current-frame movement is allowed to update immediately.
    raw_direction = classify_head_position(
        pitch,
        yaw,
        roll,
        previous_position=previous_position,
    )

    if raw_direction != previous_position:
        if (
            raw_direction == "Looking Straight"
            or abs(yaw) >= YAW_THRESHOLD
            or abs(pitch) >= PITCH_THRESHOLD
        ):
            stable_position = raw_direction

    if stable_position in (
        "Looking Left",
        "Looking Right",
        "Looking Up",
        "Looking Down",
    ):
        if head_away_start is None:
            head_away_start = current_time
    else:
        head_away_start = None

    head_position = stable_position
    last_valid_head_position = stable_position
    return stable_position


# ============================================================
# YAWN EVENT PROCESSING
# ============================================================

def process_yawn(mar):
    global yawning_active
    global yawning_start_time
    global yawning_clear_start_time
    global last_yawn_event_time
    global yawn_count

    current_time = time.time()

    if mar is None:
        return "Waiting for Driver", False

    # Keep a very short mouth history. Three frames is enough to reject an
    # isolated landmark spike without making a genuine yawn feel delayed.
    mouth_mar_history.append(float(mar))
    smooth_mar = float(np.median(list(mouth_mar_history)))

    # Use the stronger of the current and short-smoothed measurements for
    # entering a yawn. This makes a real wide-mouth expression visible while
    # still suppressing one-frame noise.
    opening_mar = max(float(mar), smooth_mar)

    if opening_mar >= YAWN_THRESHOLD:
        yawning_clear_start_time = None

        if yawning_start_time is None:
            yawning_start_time = current_time

        if not yawning_active:
            if current_time - yawning_start_time >= YAWN_CONFIRM_SECONDS:
                cooldown_ok = (
                    last_yawn_event_time is None
                    or current_time - last_yawn_event_time >= YAWN_COOLDOWN_SECONDS
                )
                if cooldown_ok:
                    yawning_active = True

        # Exactly one event for this continuous mouth-opening episode.
        if yawning_active and (
            not yawn_timestamps
            or yawn_timestamps[-1] < yawning_start_time
        ):
            if current_time - yawning_start_time >= YAWN_MIN_DURATION:
                yawn_count += 1
                yawn_timestamps.append(current_time)
                last_yawn_event_time = current_time

        return "Yes", yawning_active

    # IMPORTANT: Yawn EXIT must follow the CURRENT mouth measurement.
    # Do not require the smoothed history to also be below the release
    # threshold. A previous wide-open-mouth frame can keep the median high
    # for several frames and make the UI appear stuck on "Yes" even after
    # the driver has returned to a normal mouth position.
    #
    # A clearly closed/normal mouth exits immediately. A borderline release
    # gets only a very short confirmation to reject one noisy frame.
    if mar <= YAWN_HARD_RELEASE_THRESHOLD:
        yawning_active = False
        yawning_clear_start_time = None
        yawning_start_time = None
        return "No", False

    if mar <= YAWN_RELEASE_THRESHOLD:
        if yawning_active:
            if yawning_clear_start_time is None:
                yawning_clear_start_time = current_time
            elif current_time - yawning_clear_start_time >= YAWN_RELEASE_SECONDS:
                yawning_active = False
                yawning_clear_start_time = None
                yawning_start_time = None
        else:
            yawning_clear_start_time = None
            yawning_start_time = None

        return ("Yes" if yawning_active else "No"), yawning_active

    # The current mouth is still in the transition region. Preserve an
    # already-confirmed yawn briefly, but never let the old smoothed value
    # alone keep a completed yawn active.
    if yawning_active:
        return "Yes", True

    return "No", False


# ============================================================
# FACE VISIBILITY PROCESSING
# ============================================================

def update_face_visibility(face_detected, current_time):
    global face_missing_start
    global face_missing_duration
    global face_missing_event_active
    global face_missing_event_count
    global max_face_missing_duration

    if face_detected:
        if face_missing_event_active:
            face_missing_event_active = False

        face_missing_start = None
        face_missing_duration = 0.0
        return

    if face_missing_start is None:
        face_missing_start = current_time
        face_missing_event_active = True
        face_missing_event_count += 1

    face_missing_duration = max(
        0.0,
        current_time - face_missing_start,
    )

    max_face_missing_duration = max(
        max_face_missing_duration,
        face_missing_duration,
    )


# ============================================================
# FATIGUE ENGINE
# ============================================================

def evaluate_fatigue(
    eye_status,
    closed_duration,
    yawn_active,
    yawn_rate,
    head_position,
    face_detected=True,
):
    # A missing face is a high-priority monitoring/safety condition. The
    # product does not claim that the driver's eyes are closed.
    if not face_detected:
        return "High"

    if closed_duration >= LONG_CLOSURE_DURATION:
        return "High"

    repeated_yawns = yawn_rate >= 3

    sustained_head_away = (
        head_away_start is not None
        and time.time() - head_away_start >= HEAD_AWAY_CONFIRM_SECONDS
    )

    if closed_duration >= 0.5:
        return "Moderate"

    if yawn_active or repeated_yawns or sustained_head_away:
        return "Moderate"

    return "Low"


# ============================================================
# SAFETY ENGINE
# ============================================================

def evaluate_safety(
    face_detected,
    eye_status,
    fatigue,
    closed_duration,
    head_position,
):
    if not face_detected:
        return "Danger"

    if closed_duration >= LONG_CLOSURE_DURATION or fatigue == "High":
        return "Danger"

    if fatigue == "Moderate" or eye_status == "One Eye Closed":
        return "Warning"

    return "Safe"


# ============================================================
# SESSION STATISTICS
# ============================================================

def update_session_statistics(fatigue, safety):
    global fatigue_period_active
    global fatigue_period_count
    global warning_period_active
    global warning_period_count
    global danger_period_active
    global danger_period_count

    if fatigue in ("Moderate", "High"):
        if not fatigue_period_active:
            fatigue_period_count += 1
        fatigue_period_active = True
    else:
        fatigue_period_active = False

    if safety == "Warning":
        if not warning_period_active:
            warning_period_count += 1
        warning_period_active = True
    else:
        warning_period_active = False

    if safety == "Danger":
        if not danger_period_active:
            danger_period_count += 1
        danger_period_active = True
    else:
        danger_period_active = False


def get_session_duration():
    if monitoring_session_started_at is None:
        return 0.0
    return max(0.0, time.time() - monitoring_session_started_at)


# ============================================================
# PRODUCT RESPONSE HELPERS
# ============================================================

def product_eye_state(state):
    if state == "Open":
        return "Open"
    if state == "Closed":
        return "Closed"
    return "Waiting for Driver"


def product_combined_eye_state(state):
    if state == "Open":
        return "Open"
    if state == "Closed":
        return "Closed"
    if state == "One Eye Closed":
        return "One Eye Closed"
    return "Waiting for Driver"


def product_yawn_state(status):
    if status in ("Yes", "No"):
        return status
    return "Waiting for Driver"


def no_face_response(message=None, low_light=False, brightness=0.0):
    if message is None:
        message = (
            "Driver face is not visible. "
            "Please keep your face visible and stay focused on driving."
        )

    escalation_ready = (
        face_missing_duration >= FACE_NOT_DETECTED_ESCALATION_SECONDS
    )

    return {
        # Existing API fields.
        "face_detected": False,
        "head_position": "Face Not Visible",
        "eyes": "Waiting for Driver",
        "yawning": "Waiting for Driver",
        "fatigue": "High",
        "alert": "Danger",
        "blink_count": blink_count,
        "blink_rate": get_blink_rate(),
        "closed_duration": 0.0,
        "message": message,

        # Independent product states.
        "left_eye": "Waiting for Driver",
        "right_eye": "Waiting for Driver",
        "eye_state": "Waiting for Driver",

        # Event statistics.
        "yawn_count": yawn_count,
        "yawn_rate": get_yawn_rate(),

        # Measurement telemetry.
        "left_ear": 0.0,
        "right_ear": 0.0,
        "left_smooth_ear": 0.0,
        "right_smooth_ear": 0.0,
        "average_ear": 0.0,
        "smooth_average_ear": 0.0,
        "left_ear_ratio": 0.0,
        "right_ear_ratio": 0.0,
        "average_ear_ratio": 0.0,
        "left_close": round(LEFT_CLOSE, 3),
        "left_open": round(LEFT_OPEN, 3),
        "right_close": round(RIGHT_CLOSE, 3),
        "right_open": round(RIGHT_OPEN, 3),
        "mar": 0.0,
        "pitch": 0.0,
        "yaw": 0.0,
        "roll": 0.0,

        # Image quality.
        "low_light": low_light,
        "brightness": round(brightness, 2),

        # Calibration.
        "calibration_current": len(calibration_values_left),
        "calibration_frames": CALIBRATION_FRAMES,

        # Session statistics.
        "max_closed_duration": round(max_closed_duration, 2),
        "max_face_missing_duration": round(max_face_missing_duration, 2),
        "fatigue_period_count": fatigue_period_count,
        "warning_period_count": warning_period_count,
        "danger_period_count": danger_period_count,
        "monitoring_duration": round(get_session_duration(), 2),
        "analysis_frames": total_analysis_frames,

        # Face-visibility incident telemetry for alert escalation.
        "face_not_detected_duration": round(face_missing_duration, 2),
        "face_not_detected_escalation_seconds": FACE_NOT_DETECTED_ESCALATION_SECONDS,
        "face_not_detected_escalation_ready": escalation_ready,
        "face_not_detected_event_count": face_missing_event_count,
    }


# ============================================================
# MAIN DETECTION
# ============================================================

def detect(frame):
    global last_detection_time
    global total_analysis_frames
    global max_closed_duration

    if monitoring_session_started_at is None:
        reset_monitoring()

    current_time = time.time()
    last_detection_time = current_time
    total_analysis_frames += 1

    # --------------------------------------------------------
    # INVALID FRAME
    # --------------------------------------------------------
    if frame is None or frame.size == 0:
        update_face_visibility(False, current_time)
        reset_eye_state()
        reset_yawning_state()
        reset_head_state()

        return no_face_response(
            message=(
                "Camera frame is unavailable. "
                "Please keep your face visible and stay focused on driving."
            )
        )

    # --------------------------------------------------------
    # IMAGE PREPARATION
    # --------------------------------------------------------
    processed_frame, low_light, brightness = preprocess_frame_for_detection(frame)

    try:
        rgb = cv2.cvtColor(processed_frame, cv2.COLOR_BGR2RGB)
    except Exception as exc:
        print("Color conversion error:", exc)
        update_face_visibility(False, current_time)
        reset_eye_state()
        reset_yawning_state()
        reset_head_state()
        return no_face_response(
            low_light=low_light,
            brightness=brightness,
        )

    # --------------------------------------------------------
    # FACE LANDMARKS
    # --------------------------------------------------------
    try:
        results = face_mesh.process(rgb)
    except Exception as exc:
        print("MediaPipe processing error:", exc)
        update_face_visibility(False, current_time)
        reset_eye_state()
        reset_yawning_state()
        reset_head_state()
        return no_face_response(
            message=(
                "Driver face could not be detected reliably. "
                "Please keep your face visible."
            ),
            low_light=low_light,
            brightness=brightness,
        )

    # --------------------------------------------------------
    # DRIVER NOT DETECTED
    # --------------------------------------------------------
    if results is None or not results.multi_face_landmarks:
        update_face_visibility(False, current_time)

        # Face-dependent states are cleared after the visibility loss is
        # confirmed. No false eye/yawn/head/blink events are generated.
        reset_eye_state()
        reset_yawning_state()
        reset_head_state()

        print("\n--------------------------------------")
        print("DRIVER NOT DETECTED")
        print(f"Face Missing    : {face_missing_duration:.2f}s")
        print(f"Escalation Ready: {face_missing_duration >= FACE_NOT_DETECTED_ESCALATION_SECONDS}")
        print(f"Blink Count     : {blink_count}")
        print(f"Blink Rate      : {get_blink_rate()}/min")
        print(f"Yawn Count      : {yawn_count}")
        print("--------------------------------------")

        return no_face_response(
            low_light=low_light,
            brightness=brightness,
        )

    # --------------------------------------------------------
    # DRIVER DETECTED
    # --------------------------------------------------------
    update_face_visibility(True, current_time)

    landmarks = results.multi_face_landmarks[0].landmark

    # --------------------------------------------------------
    # HEAD MEASUREMENT
    # --------------------------------------------------------
    raw_head_position, pitch, yaw, roll = estimate_head_pose(
        processed_frame,
        landmarks,
    )

    stable_head_position = stabilize_head_position(
        raw_head_position,
        pitch,
        yaw,
        roll,
    )

    # --------------------------------------------------------
    # EYE MEASUREMENTS
    # --------------------------------------------------------
    left_ear = eye_aspect_ratio(landmarks, LEFT_EYE)
    right_ear = eye_aspect_ratio(landmarks, RIGHT_EYE)

    average_ear = (
        (left_ear + right_ear) / 2.0
        if left_ear is not None and right_ear is not None
        else None
    )

    if left_ear is not None:
        left_ear_history.append(left_ear)
    if right_ear is not None:
        right_ear_history.append(right_ear)

    left_smooth_ear = (
        float(np.median(list(left_ear_history)))
        if left_ear_history
        else None
    )
    right_smooth_ear = (
        float(np.median(list(right_ear_history)))
        if right_ear_history
        else None
    )

    smooth_values = [
        value
        for value in (left_smooth_ear, right_smooth_ear)
        if value is not None
    ]
    smooth_average_ear = (
        sum(smooth_values) / len(smooth_values)
        if smooth_values
        else None
    )

    # --------------------------------------------------------
    # CALIBRATION
    # --------------------------------------------------------
    if not calibration_complete:
        calibrate_eyes(left_ear, right_ear)

    # --------------------------------------------------------
    # EAR RATIOS
    # --------------------------------------------------------
    left_ear_ratio = (
        left_ear / left_baseline_ear
        if left_ear is not None and left_baseline_ear and left_baseline_ear > 0.0
        else None
    )
    right_ear_ratio = (
        right_ear / right_baseline_ear
        if right_ear is not None and right_baseline_ear and right_baseline_ear > 0.0
        else None
    )

    baseline_average = (
        (left_baseline_ear + right_baseline_ear) / 2.0
        if (
            left_baseline_ear is not None
            and right_baseline_ear is not None
            and left_baseline_ear > 0.0
            and right_baseline_ear > 0.0
        )
        else None
    )

    average_ear_ratio = (
        average_ear / baseline_average
        if average_ear is not None and baseline_average and baseline_average > 0.0
        else None
    )

    # --------------------------------------------------------
    # EYE STATE + BLINK EVENTS
    # --------------------------------------------------------
    (
        left_state,
        right_state,
        eye_state,
        active_closed_duration,
    ) = process_blink(
        left_ear,
        right_ear,
        left_smoothed_ear=left_smooth_ear,
        right_smoothed_ear=right_smooth_ear,
    )

    if active_closed_duration > max_closed_duration:
        max_closed_duration = active_closed_duration

    # --------------------------------------------------------
    # MOUTH + YAWN EVENTS
    # --------------------------------------------------------
    mar = mouth_open(landmarks)
    yawn_status, yawn_active = process_yawn(mar)

    # --------------------------------------------------------
    # FATIGUE
    # --------------------------------------------------------
    fatigue = evaluate_fatigue(
        eye_status=eye_state,
        closed_duration=active_closed_duration,
        yawn_active=yawn_active,
        yawn_rate=get_yawn_rate(),
        head_position=stable_head_position,
        face_detected=True,
    )

    # --------------------------------------------------------
    # SAFETY
    # --------------------------------------------------------
    safety = evaluate_safety(
        face_detected=True,
        eye_status=eye_state,
        fatigue=fatigue,
        closed_duration=active_closed_duration,
        head_position=stable_head_position,
    )

    update_session_statistics(fatigue, safety)

    # --------------------------------------------------------
    # PRODUCT MESSAGE
    # --------------------------------------------------------
    if safety == "Safe":
        message = "Driver is alert and focused."
    elif safety == "Warning":
        message = "Please stay focused on the road."
    else:
        message = "Immediate attention required. Please focus on driving."

    # --------------------------------------------------------
    # DEBUG OUTPUT
    # --------------------------------------------------------
    print("\n--------------------------------------")
    print(f"Left EAR          : {left_ear:.3f}" if left_ear is not None else "Left EAR          : N/A")
    print(f"Right EAR         : {right_ear:.3f}" if right_ear is not None else "Right EAR         : N/A")
    print(f"Left Smooth EAR   : {left_smooth_ear:.3f}" if left_smooth_ear is not None else "Left Smooth EAR   : N/A")
    print(f"Right Smooth EAR  : {right_smooth_ear:.3f}" if right_smooth_ear is not None else "Right Smooth EAR  : N/A")
    print(f"Average EAR       : {average_ear:.3f}" if average_ear is not None else "Average EAR       : N/A")
    print(f"Smooth Average    : {smooth_average_ear:.3f}" if smooth_average_ear is not None else "Smooth Average    : N/A")
    print(f"Left EAR Ratio    : {left_ear_ratio:.3f}" if left_ear_ratio is not None else "Left EAR Ratio    : N/A")
    print(f"Right EAR Ratio   : {right_ear_ratio:.3f}" if right_ear_ratio is not None else "Right EAR Ratio   : N/A")
    print(f"Average EAR Ratio : {average_ear_ratio:.3f}" if average_ear_ratio is not None else "Average EAR Ratio : N/A")
    print(f"Left Close        : {LEFT_CLOSE:.3f}")
    print(f"Left Open         : {LEFT_OPEN:.3f}")
    print(f"Right Close       : {RIGHT_CLOSE:.3f}")
    print(f"Right Open        : {RIGHT_OPEN:.3f}")
    print(f"MAR               : {mar:.3f}" if mar is not None else "MAR               : N/A")
    current_smooth_mar = (float(np.median(list(mouth_mar_history))) if mouth_mar_history else None)
    print(f"Yawn Smooth MAR   : {current_smooth_mar:.3f}" if current_smooth_mar is not None else "Yawn Smooth MAR   : N/A")
    print(f"Head Position     : {stable_head_position}")
    print(f"Pitch             : {pitch:.2f}")
    print(f"Yaw               : {yaw:.2f}")
    print(f"Roll              : {roll:.2f}")
    print(f"Left Eye          : {product_eye_state(left_state)}")
    print(f"Right Eye         : {product_eye_state(right_state)}")
    print(f"Eyes Status       : {product_combined_eye_state(eye_state)}")
    print(f"Yawning           : {product_yawn_state(yawn_status)}")
    print(f"Blink Count       : {blink_count}")
    print(f"Blink Rate        : {get_blink_rate()}/min")
    print(f"Yawn Count        : {yawn_count}")
    print(f"Yawn Rate         : {get_yawn_rate()}/min")
    print(f"Closed Time       : {active_closed_duration:.2f}s")
    print(f"Max Closed Time   : {max_closed_duration:.2f}s")
    print(f"Fatigue           : {fatigue}")
    print(f"Safety            : {safety}")
    print(f"Low Light         : {low_light}")
    print(f"Brightness        : {brightness:.2f}")
    print(f"Calibration       : {len(calibration_values_left)}/{CALIBRATION_FRAMES}")
    print("--------------------------------------")

    # --------------------------------------------------------
    # STABLE API RESPONSE
    # --------------------------------------------------------
    return {
        # Existing API fields.
        "face_detected": True,
        "head_position": stable_head_position,
        "eyes": product_combined_eye_state(eye_state),
        "yawning": product_yawn_state(yawn_status),
        "fatigue": fatigue,
        "alert": safety,
        "blink_count": blink_count,
        "blink_rate": get_blink_rate(),
        "closed_duration": round(active_closed_duration, 2),
        "message": message,

        # Independent eye states.
        "left_eye": product_eye_state(left_state),
        "right_eye": product_eye_state(right_state),
        "eye_state": product_combined_eye_state(eye_state),

        # Yawn events.
        "yawn_count": yawn_count,
        "yawn_rate": get_yawn_rate(),

        # EAR telemetry.
        "left_ear": round(left_ear, 3) if left_ear is not None else 0.0,
        "right_ear": round(right_ear, 3) if right_ear is not None else 0.0,
        "left_smooth_ear": round(left_smooth_ear, 3) if left_smooth_ear is not None else 0.0,
        "right_smooth_ear": round(right_smooth_ear, 3) if right_smooth_ear is not None else 0.0,
        "average_ear": round(average_ear, 3) if average_ear is not None else 0.0,
        "smooth_average_ear": round(smooth_average_ear, 3) if smooth_average_ear is not None else 0.0,
        "left_ear_ratio": round(left_ear_ratio, 3) if left_ear_ratio is not None else 0.0,
        "right_ear_ratio": round(right_ear_ratio, 3) if right_ear_ratio is not None else 0.0,
        "average_ear_ratio": round(average_ear_ratio, 3) if average_ear_ratio is not None else 0.0,

        # Threshold telemetry.
        "left_close": round(LEFT_CLOSE, 3),
        "left_open": round(LEFT_OPEN, 3),
        "right_close": round(RIGHT_CLOSE, 3),
        "right_open": round(RIGHT_OPEN, 3),

        # Mouth/head telemetry.
        "mar": round(mar, 3) if mar is not None else 0.0,
        "pitch": round(pitch, 2),
        "yaw": round(yaw, 2),
        "roll": round(roll, 2),

        # Image quality.
        "low_light": low_light,
        "brightness": round(brightness, 2),

        # Calibration.
        "calibration_current": len(calibration_values_left),
        "calibration_frames": CALIBRATION_FRAMES,

        # Session statistics.
        "max_closed_duration": round(max_closed_duration, 2),
        "max_face_missing_duration": round(max_face_missing_duration, 2),
        "fatigue_period_count": fatigue_period_count,
        "warning_period_count": warning_period_count,
        "danger_period_count": danger_period_count,
        "monitoring_duration": round(get_session_duration(), 2),
        "analysis_frames": total_analysis_frames,

        # Face visibility / alert escalation telemetry.
        "face_not_detected_duration": round(face_missing_duration, 2),
        "face_not_detected_escalation_seconds": FACE_NOT_DETECTED_ESCALATION_SECONDS,
        "face_not_detected_escalation_ready": False,
        "face_not_detected_event_count": face_missing_event_count,
    }
