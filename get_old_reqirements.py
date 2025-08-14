import requests
from datetime import datetime, timezone

def get_version_at_time(package_name, target_date):
    """
    Get the latest version of a package available on PyPI at a specific UTC date.
    :param package_name: str, name of the package
    :param target_date: datetime, UTC datetime to check
    :return: str, version or None if not found
    """
    url = f"https://pypi.org/pypi/{package_name}/json"
    resp = requests.get(url)
    if resp.status_code != 200:
        print(f"Package {package_name} not found on PyPI.")
        return None

    data = resp.json()
    releases = data.get("releases", {})
    latest_version = None
    latest_time = None

    for version, files in releases.items():
        for file in files:
            upload_time = file.get("upload_time_iso_8601")
            if upload_time:
                upload_dt = datetime.fromisoformat(upload_time.replace("Z", "+00:00"))
                if upload_dt <= target_date:
                    if (latest_time is None) or (upload_dt > latest_time):
                        latest_time = upload_dt
                        latest_version = version

    return latest_version

if __name__ == "__main__":
    infile = "requirements.txt"
    new_requirements = []
    date_str = "2022-03-22"
    target_dt = datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)

    with open(infile, "r") as f:
        packages = [line.strip() for line in f if line.strip() and not line.startswith("#")]
        for package in packages:
            if ">=" in package or "==" in package:
              new_requirements.append(package)
              continue
            version = get_version_at_time(package, target_dt)
            new_requirements.append(f"{package}=={version}" if version else package)

    with open("old_requirements.txt", "w") as f:
        for req in new_requirements:
            f.write(req + "\n")
    print("Old requirements saved to old_requirements.txt")