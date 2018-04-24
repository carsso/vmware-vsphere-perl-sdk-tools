#!/usr/bin/perl
use strict;
use Data::Dumper;
use VMware::VIRuntime;

#
#   Use this script to clone a vm template to multiple vms with random name following a pattern
#   Fill the informations below
#   Usage : perl clonetemplate.pl <number_of_vms_to_deploy>
#
#   This script has been created thanks to these blog posts :
#    - https://room28.it/index.php/2016/07/11/use-vmware-perl-sdk-to-manage-a-vsphere-infrastructure/
#    - https://room28.it/index.php/2016/10/10/deploy-a-linux-vm-using-customization-wizard-using-perl-sdk/#more-80
#    - https://room28.it/index.php/2016/11/24/use-linked-clone-instead-of-full-clone-to-create-vms/
#

Opts::set_option('server', 'pcc-xxx-xxx-xxx-xxx.ovh.com');
Opts::set_option('username', 'sdkuser');
Opts::set_option('password', 'xxxxxxxx');


print "Connecting \n"; 

Util::connect(); 

my $numberOfVmsToDeploy = int $ARGV[0] || 1;

### Custom properties. To fill with your environment requirements
my $templateName = 'template-myvm';
my $datacenterName = 'pcc-xxx-xxx-xxx-xxx_datacenter1';
my $clusterName = 'Cluster1';
my $datastoreName = 'pcc-11111';
my $folderName = 'myfolder';
my $baseVmName = 'myvmname';
my $useLinkedClone = 1; # 0 to full clone, 1 to linked clone (see https://room28.it/index.php/2016/11/24/use-linked-clone-instead-of-full-clone-to-create-vms/)

### Checks 
print "Getting Datacenter view \n";
my $DatacenterView = Vim::find_entity_view(
	'view_type' => 'Datacenter',
	'filter' => {
		'name' => $datacenterName
	}
);
!$DatacenterView and die('Failed to get Datacenter view');

print "Getting Template view\n";
my $VMView = Vim::find_entity_view(
	'view_type' => 'VirtualMachine',
	'filter' => {
		'name' => $templateName
	},
	'begin_entity' => $DatacenterView,
);
!$VMView and die('Failed to get Template view');
my $currentSnapshot = $VMView->snapshot->currentSnapshot;

print "Getting destination cluster view\n";
my $ClusterView = Vim::find_entity_view(
	'view_type' => 'ClusterComputeResource',
	'begin_entity' => $DatacenterView,
	'filter' => { 
		'name' => $clusterName 
	}
);
!$ClusterView and die('Failed to get cluster view');

print "Getting destination datastore view \n";
my $DatastoreView = Vim::find_entity_view(
	'view_type' => 'Datastore',
	'begin_entity' => $DatacenterView,
	'filter' => {
		'name' => $datastoreName
	}
);
!$DatastoreView and die('Failed to get datastore view');

print "Getting destination folder view\n";
my $FolderView = Vim::find_entity_view(
	'view_type' => 'Folder',
	'begin_entity' => $DatacenterView,
	'filter' => { 
		'name' => $folderName 
	}
);
!$FolderView and die $FolderView;

### Virtual Hardware configuration

my $VirtualMachineRelocateSpec = VirtualMachineRelocateSpec->new(
	'datastore' => $DatastoreView,
	'diskMoveType'	=> $useLinkedClone ? 'createNewChildDiskBacking' : 'moveAllDiskBackingsAndAllowSharing',
	'pool' => $ClusterView->resourcePool,
);
my $VirtualMachineConfigSpec = new VirtualMachineConfigSpec;

my $VirtualMachineCloneSpec = VirtualMachineCloneSpec->new(
	'config' => $VirtualMachineConfigSpec,
	'location' => $VirtualMachineRelocateSpec,
	'powerOn' => 'true',
	'template' => 'false',
	'snapshot' => $currentSnapshot,
);

print "Will deploy $numberOfVmsToDeploy VMs\n";
for(my $i = 1; $i <= $numberOfVmsToDeploy; $i++)
{
	my $vmName = $baseVmName.'-'.int(rand()*1000000);

	print "Deploying VM n°$i : $vmName\n";

	### Cloning operation
	eval{
		$VMView->CloneVM(
			'folder' => $FolderView,
			'name' => $vmName,
			'spec' => $VirtualMachineCloneSpec,
		);
	};
	if($@)
	{
		my @report = ('Error crearting VM : ', $@);
		print Dumper(@report);
		Util::disconnect();
		die;
	}
}
Util::disconnect();
