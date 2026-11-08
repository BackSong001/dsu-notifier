"""설치 인증정보가 백업이나 기기 이전으로 복제되지 않는지 검사한다."""
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET


class AndroidReleaseConfigTest(unittest.TestCase):
    def test_device_identity_is_excluded_from_backup_and_transfer(self):
        main = Path(__file__).resolve().parents[1] / 'android/app/src/main'
        application = ET.parse(main / 'AndroidManifest.xml').getroot().find('application')
        android = '{http://schemas.android.com/apk/res/android}'
        self.assertEqual(application.get(android + 'allowBackup'), 'false')
        self.assertEqual(application.get(android + 'fullBackupContent'), 'false')
        resource = application.get(android + 'dataExtractionRules')
        self.assertTrue(resource and resource.startswith('@xml/'))
        rules = ET.parse(main / 'res/xml' / (resource.split('/')[1] + '.xml')).getroot()
        for section in ['cloud-backup', 'device-transfer']:
            with self.subTest(section=section):
                exclusions = rules.find(section).findall('exclude')
                self.assertTrue(any(item.get('domain') == 'sharedpref' and item.get('path') in ['.', 'device_identity.xml'] for item in exclusions), 'Device credentials must not be copied')


if __name__ == '__main__':
    unittest.main()
