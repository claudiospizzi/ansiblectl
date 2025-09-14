
$tag = 'dev'

docker build -t "claudiospizzi/ansiblectl:$tag" --build-arg 'ANSIBLE_VERSION=11.10.0-1ppa~noble' .

Import-Module './AnsibleCtl/AnsibleCtl.psd1' -Force

ansiblectl -RepositoryPath 'C:\Users\ClaudioSpizzi\Workspace\Casa\casa-ansible' -ContainerImage 'claudiospizzi/ansiblectl:dev' -OnePasswordSshKeys Casa
