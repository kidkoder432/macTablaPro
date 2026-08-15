import datetime
import requests

# Base URL extracted from the fetch comment
FORM_URL = "https://docs.google.com/forms/u/0/d/e/1FAIpQLSdmGU8uxDgCLlpqIs2uoLcCn1mKd33WjO-SOeDL01mPxKpPkg/formResponse"

# --- 1. NEW FIELD ID MAPPINGS ---
# Mapped directly from the commented fetch body parameters
FIELDS = {
    "student_id": "entry.1742760532",
    "first_name": "entry.1992748701",
    "last_name": "entry.1182588695",
    "email": "entry.1838437624",
    "batch": "entry.2040019182",
    "minutes_practiced": "entry.1586397793",
    "practice_summary": "entry.193868850",
    "sankalp_word": "entry.1865891008",  # Additional field present in this form
    "year": "entry.737772668_year",
    "month": "entry.737772668_month",
    "day": "entry.737772668_day",
}


def log_practice(
    student_id: str,
    first_name: str,
    last_name: str,
    email: str,
    batch: str,
    minutes: int,
    practice_summary: str,
    samkalp_word: str = "",
    date: datetime.date = None,
):
    """Submits practice log entry to the updated Google Form."""
    if date is None:
        date = datetime.date.today()

    payload = {
        FIELDS["student_id"]: student_id,
        FIELDS["first_name"]: first_name,
        FIELDS["last_name"]: last_name,
        FIELDS["email"]: email,
        FIELDS["batch"]: batch,
        FIELDS["minutes_practiced"]: str(minutes),
        FIELDS["practice_summary"]: practice_summary,
        FIELDS["sankalp_word"]: samkalp_word,
        FIELDS["year"]: str(date.year),
        FIELDS["month"]: str(date.month),
        FIELDS["day"]: str(date.day),
        # Internal metadata flags from the fetch trace
        "pageHistory": "0",
        "fvv": "1",
    }

    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0"
        )
    }

    response = requests.post(FORM_URL, data=payload, headers=headers)

    if response.status_code == 200:
        print(f"Successfully logged entry for {first_name} {last_name}!")
    else:
        print(f"Failed to log entry. HTTP Status: {response.status_code}")


# --- 2. EXECUTION ---
if __name__ == "__main__":
    log_practice(
        student_id="31415926535",
        first_name="test",
        last_name="test",
        email="findprajju@gmail.com",
        batch="Test Batch",
        minutes=1,
        practice_summary="This is a test response for a project I am working on. Please ignore thi response. ",
        samkalp_word="DO NOT COUNT THIS RESPONSE IN SANKALP. THIS IS ONLY A TEST.",
        date=datetime.date(1970, 1, 1),
    )