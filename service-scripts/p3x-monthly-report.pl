
use Data::Dumper;
use strict;
use Bio::KBase::AppService::SchedulerDB;
use List::MoreUtils qw(first_index);

my $db = Bio::KBase::AppService::SchedulerDB->new();

my $dbh = $db->dbh;

my %app_values;

my $start = '2021-10-01 00:00:00';
my $end = '2021-11-01:00:00:00';
my $include_staff = 1;

#
# Pull time info for completed runs
#

my $staff_check = $include_staff ? "" : "AND is_collaborator = 0 AND is_staff = 0";

my $data = $dbh->selectall_hashref(qq(SELECT application_id,
				     ROUND(AVG(TIMESTAMPDIFF(SECOND, start_time ,finish_time)))  AS avg,
				     MAX(TIMESTAMPDIFF(SECOND, start_time ,finish_time)) AS max,
				     MIN(TIMESTAMPDIFF(SECOND, start_time ,finish_time)) AS min,
				     ROUND(STD(TIMESTAMPDIFF(SECOND, start_time ,finish_time))) AS std,

				     ROUND(AVG(TIMESTAMPDIFF(SECOND, submit_time, start_time)))  AS wait_avg,
				     MAX(TIMESTAMPDIFF(SECOND, submit_time, start_time)) AS wait_max,
				     MIN(TIMESTAMPDIFF(SECOND, submit_time, start_time)) AS wait_min,
				     ROUND(STD(TIMESTAMPDIFF(SECOND, start_time ,finish_time))) AS wait_std,

				     COUNT(TIMESTAMPDIFF(SECOND, start_time ,finish_time)) AS completed
				     FROM Task LEFT OUTER JOIN ServiceUser on Task.owner = ServiceUser.id
				     WHERE state_code = 'C' AND application_id NOT IN ('Date', 'Sleep') AND
				     submit_time >= ? AND
				      submit_time < ? 
				     $staff_check
				     GROUP BY application_id), 'application_id', undef, $start, $end);

#
# Pull total and failed counts.
#

my $total = $dbh->selectall_hashref(qq(SELECT application_id,
				       COUNT(Task.id) as total
				       FROM Task LEFT OUTER JOIN ServiceUser on Task.owner = ServiceUser.id
				       WHERE application_id NOT IN ('Date', 'Sleep') AND
				       state_code IN ('C', 'F') AND
				       submit_time >= ? AND
				       submit_time < ?
				       $staff_check
				       GROUP BY application_id), 'application_id', undef, $start, $end);

my $failed = $dbh->selectall_hashref(qq(SELECT application_id,
					COUNT(Task.id) as failed
					FROM Task LEFT OUTER JOIN ServiceUser on Task.owner = ServiceUser.id
					WHERE application_id NOT IN ('Date', 'Sleep') AND
					state_code = 'F' AND 
					submit_time >= ? AND
					submit_time < ?
					$staff_check
					GROUP BY application_id), 'application_id', undef, $start, $end);
while (my($app, $vals) = each %$total)
{
    $data->{$app}->{total} = $vals->{total};
}

while (my($app, $vals) = each %$failed)
{
    $data->{$app}->{failed} = $vals->{failed};
}

my @cols = qw(total completed failed min avg max std wait_min wait_avg wait_max wait_std);
print join("\t", 'application', @cols), "\n";
	   
for my $app (sort keys %$data)
{
    my $vals = $data->{$app};
    print join("\t", $app, @$vals{@cols}), "\n";
}
