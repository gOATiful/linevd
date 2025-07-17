from datetime import datetime, timezone, tzinfo

import requests

search_date = datetime(2022, 3, 30, tzinfo=timezone.utc) # date of last commit to linevd


def get_used_libraries():
    with open("requirements.txt") as infile:
        return [x.split(">")[0].strip() for x in infile.readlines()]


def find_closest_date(needle, stack):
    for release_date in stack:
        iso_release_date = datetime.fromisoformat(release_date)
        if iso_release_date < needle:
            return release_date
    return ""


def find_variant(libname):
    import re
    regex = re.compile("(\\[.*\\])")
    matches = re.findall(pattern=regex, string=libname)
    if len(matches) == 1:
        return matches[0]
    else:
        return ""


libs = get_used_libraries()
new_requirements = []

for lib in libs:
    lib_variant = find_variant(lib)
    lib = lib.replace(lib_variant, "")
    res = requests.get(f"https://pypi.org/pypi/{lib}/json")
    res.raise_for_status()
    data = res.json()
    version_timestamps = {}
    for version, release_data in data["releases"].items():
        if len(release_data) != 0:
            version_timestamps[release_data[0]["upload_time_iso_8601"]] = version
    release_dates = list(version_timestamps.keys())
    release_dates.sort(reverse=True)
    best_release_date = find_closest_date(search_date, release_dates)
    selected_version = version_timestamps[best_release_date]
    new_requirements.append(f"{lib}{lib_variant}=={selected_version}\n")
    
with open("requirements_fixed.txt", "w") as outfile:
    outfile.writelines(new_requirements)
    
            