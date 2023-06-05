// ignore_for_file: constant_identifier_names

class Strings {
// Dexcom Share API base urls
  static const DEXCOM_BASE_URL =
      "https://share2.dexcom.com/ShareWebServices/Services";
  static const DEXCOM_BASE_URL_OUS =
      "https://shareous1.dexcom.com/ShareWebServices/Services";

// Dexcom Share API endpoints
  static const DEXCOM_LOGIN_ID_ENDPOINT = "General/LoginPublisherAccountById";
  static const DEXCOM_AUTHENTICATE_ENDPOINT =
      "General/AuthenticatePublisherAccount";
  static const DEXCOM_VERIFY_SERIAL_NUMBER_ENDPOINT =
      ("Publisher/CheckMonitoredReceiverAssignmentStatus");
  static const DEXCOM_GLUCOSE_READINGS_ENDPOINT =
      "Publisher/ReadPublisherLatestGlucoseValues";

  static const DEXCOM_APPLICATION_ID = "d89443d2-327c-4a6f-89e5-496bbb0317db";

// Dexcom error strings
  static const ACCOUNT_ERROR_USERNAME_NULL_EMPTY = "Username null or empty";
  static const ACCOUNT_ERROR_PASSWORD_NULL_EMPTY = "Password null or empty";
  static const SESSION_ERROR_ACCOUNT_ID_NULL_EMPTY = "Accound ID null or empty";
  static const SESSION_ERROR_ACCOUNT_ID_DEFAULT = "Accound ID default";
  static const ACCOUNT_ERROR_ACCOUNT_NOT_FOUND = "Account not found";
  static const ACCOUNT_ERROR_PASSWORD_INVALID = "Password not valid";
  static const ACCOUNT_ERROR_MAX_ATTEMPTS =
      "Maximum authentication attempts exceeded";
  static const ACCOUNT_ERROR_UNKNOWN = "Account error";

  static const SESSION_ERROR_SESSION_ID_NULL = "Session ID null";
  static const SESSION_ERROR_SESSION_ID_DEFAULT = "Session ID default";
  static const SESSION_ERROR_SESSION_NOT_VALID = "Session ID not valid";
  static const SESSION_ERROR_SESSION_NOT_FOUND = "Session ID not found";

  static const ARGUEMENT_ERROR_MINUTES_INVALID =
      "Minutes must be between 1 and 1440";
  static const ARGUEMENT_ERROR_MAX_COUNT_INVALID =
      "Max count must be between 1 and 288";
  static const ARGUEMENT_ERROR_SERIAL_NUMBER_NULL_EMPTY =
      "Serial number null or empty";

// Other
  static const DEXCOM_TREND_DESCRIPTIONS = [
    "",
    "rising quickly",
    "rising",
    "rising slightly",
    "steady",
    "falling slightly",
    "falling",
    "falling quickly",
    "unable to determine trend",
    "trend unavailable",
  ];

  static const DEXCOM_TREND_DIRECTIONS = {
    "None": 0,
    "DoubleUp": 1,
    "SingleUp": 2,
    "FortyFiveUp": 3,
    "Flat": 4,
    "FortyFiveDown": 5,
    "SingleDown": 6,
    "DoubleDown": 7,
    "NotComputable": 8,
    "RateOutOfRange": 9,
  };

  static const DEXCOM_TREND_ARROWS = [
    "",
    "↑↑",
    "↑",
    "↗",
    "→",
    "↘",
    "↓",
    "↓↓",
    "?",
    "-"
  ];
}
