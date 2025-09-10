
$tag = 'dev'

docker build -t "claudiospizzi/ansiblectl:$tag" .

Import-Module './AnsibleCtl/AnsibleCtl.psd1' -Force

ansiblectl -RepositoryPath 'C:\Users\ClaudioSpizzi\Workspace\Casa\casa-ansible' -OnePasswordSshKeys Casa
