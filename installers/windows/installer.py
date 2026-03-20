import os
import sys
import hashlib
import requests
from pathlib import Path
import subprocess

# Constants
REPO_OWNER = 'nurchikoo19'
REPO_NAME = 'finapp'
INSTALL_DIR = Path.home() / 'finapp'
APP_NAME = 'FinApp'
DESKTOP_SHORTCUT = Path.home() / 'Desktop' / f'{APP_NAME}.lnk'
START_MENU_SHORTCUT = Path.home() / 'AppData' / 'Roaming' / 'Microsoft' / 'Windows' / 'Start Menu' / 'Programs' / f'{APP_NAME}.lnk'

# Ensure the installation directory exists
INSTALL_DIR.mkdir(exist_ok=True)

def download_file(url, dst):
    print('📥 Downloading the latest release...')
    r = requests.get(url, stream=True)
    if r.status_code != 200:
        print('❌ Failed to download the file!')
        sys.exit(1)

    with open(dst, 'wb') as f:
        total_length = int(r.headers.get('content-length', 0))
        dl = 0
        for data in r.iter_content(chunk_size=4096):
            dl += len(data)
            f.write(data)
            done = int(50 * dl / total_length)
            print(f'[{done * "#"}{(50-done) * " "}] {dl}/{total_length} bytes', end='\r')
    print('\n✅ Download completed!')

def verify_sha256(file_path, expected_hash):
    print('🔍 Verifying file integrity...')
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256.update(chunk)
    actual_hash = sha256.hexdigest()
    if actual_hash != expected_hash:
        print('❌ File integrity check failed!')
        sys.exit(1)
    print('✅ File integrity verified.')

def create_shortcut(target, shortcut_name, shortcut_path):
    print('🖱️ Creating shortcut...')
    shell = Dispatch('WScript.Shell')
    shortcut = shell.CreateShortCut(str(shortcut_path))
    shortcut.Targetpath = str(target)
    shortcut.WorkingDirectory = str(INSTALL_DIR)
    shortcut.save()
    print(f'✅ Shortcut created at {shortcut_path}')

def add_to_path():
    print('📂 Adding installation directory to system PATH...')
    current_path = os.environ.get('PATH')
    if str(INSTALL_DIR) not in current_path:
        os.environ['PATH'] = current_path + os.pathsep + str(INSTALL_DIR)
        print('✅ Installation directory added to PATH.')
    else:
        print('⚠️ Installation directory already in PATH.')

def launch_application():
    print('🚀 Launching the application...')
    subprocess.Popen([str(INSTALL_DIR / 'finapp.exe')])

def main():
    # Download the latest release
    download_url = f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/latest'
    r = requests.get(download_url)
    latest_release = r.json()
    asset = latest_release['assets'][0]  # Assuming the first asset is the executable
    download_file(asset['browser_download_url'], INSTALL_DIR / asset['name'])
    
    # Verify the file integrity
    expected_hash = asset['size']  # Update this with the correct hash
    verify_sha256(INSTALL_DIR / asset['name'], expected_hash)
    
    # Remove previous versions
    for item in INSTALL_DIR.glob('*'):
        if item.is_file():
            item.unlink()
    
    # Install the new version
    # Assuming the installation was just unzipped or copied
    add_to_path()  # Update system PATH
    create_shortcut(INSTALL_DIR / asset['name'], APP_NAME, DESKTOP_SHORTCUT)
    create_shortcut(INSTALL_DIR / asset['name'], APP_NAME, START_MENU_SHORTCUT)
    launch_application()

if __name__ == '__main__':
    main()