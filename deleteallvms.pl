#!/usr/bin/perl
use strict;
use Data::Dumper;
use VMware::VIRuntime;

#
#   Use this script to stop and delete all vms with name following a pattern
#   Fill the informations below
#   Usage : perl deleteallvms.pl
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


### Custom properties. To fill with your environment requirements
my $templateName = 'template-myvm';
my $datacenterName = 'pcc-xxx-xxx-xxx-xxx_datacenter1';
my $vmName = qr/^myvmname-\d+/;
my $folderName = 'myfolder';


### Checks 
print "Getting Datacenter view \n";
my $DatacenterView = Vim::find_entity_view(
	'view_type' => 'Datacenter',
	'filter' => {
		'name' => $datacenterName
	}
);
!$DatacenterView and die('Failed to get Datacenter view');

print "Getting destination folder view\n";
my $FolderView = Vim::find_entity_view(
	'view_type' => 'Folder',
	'begin_entity' => $DatacenterView,
	'filter' => { 
		'name' => $folderName 
	}
);
!$FolderView and die $FolderView;

print "Getting VM views\n";
my $VMViews = Vim::find_entity_views(
	'view_type' => 'VirtualMachine',
	'filter' => {
		'name' => $vmName
	},
	'begin_entity' => $FolderView,
);
!$VMViews and die('Failed to get VM views');

foreach my $VMView (@$VMViews)
{
	print "Will delete VM ".$VMView->config->name."\n";
}

print "Press enter to confirm\n";
<STDIN>;
foreach my $VMView (@$VMViews)
{
	my $vmName = $VMView->config->name;
	print "Stopping VM $vmName\n";
	### Deleting operation
	eval{
		$VMView->PowerOffVM();
	};
	if($@)
	{
		my @report = ('Error stopping VM : ', $@);
		print Dumper(@report);
		Util::disconnect();
		die;
	}
	print "Deleting VM $vmName\n";
	eval{
		$VMView->Destroy();
	};
	if($@)
	{
		my @report = ('Error deleting VM : ', $@);
		print Dumper(@report);
		Util::disconnect();
		die;
	}
	print "VM $vmName deleted\n";
}
