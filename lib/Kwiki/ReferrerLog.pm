package Kwiki::ReferrerLog;
use strict;
use warnings;
use Kwiki::Display '-Base';
use mixin 'Kwiki::Installer';
use Storable qw(lock_store lock_retrieve);
use POSIX qw(strftime);
our $VERSION = '0.01';

our $DAY_SECONDS = 86400;

const config_file => 'referrerlog.yaml';
const class_id    => 'referrerlog';
const class_title => 'ReferrerLog Display';
const css_file    => 'referrerlog.css';
const log_file    => 'referrers.log';



sub register {
    $self->SUPER::register(@_);

    my $registry = shift;
    $registry->add(action => 'referrerlog');
    $registry->add(toolbar => 'referrerlog_button',
                   template => 'referrerlog_button.html',
                  );
}

sub display {
    $self->log_referrer;
    $self->SUPER::display(@_);
}


sub referrerlog {
    my $log = $self->load_log;
    my $refs = [];
    foreach (keys %$log) {
      push @$refs, {'visitcount' => $log->{$_}->[0], 'time'   => $log->{$_}->[1],
                    'uri'        => $log->{$_}->[2], 'refuri' => $_ };
    }

    # puts the latest referrers on the top of the list
    @$refs = sort { $a->{'time'} <=> $b->{'time'} } @$refs;

    $self->render_screen(
        screen_title => $self->class_title,
        'log' => $refs,
    );
}


sub log_referrer {
    my $ref = $ENV{HTTP_REFERER};
    my $base_uri = eval {$self->hub->config->site_uri};
    die "The configuration parameter 'site_uri' has to be specified".
        "in the config file! \n $@"
      if $@;

    if ( $ref && $ref !~ /^$base_uri/ ) {
        my $log = $self->load_log;
        $log->{$ref}->[0]++ ;      # referrer count
        $log->{$ref}->[1] = time;  # time
        $log->{$ref}->[2] = $self->pages->current->uri;  # where did it go?

        $self->delete_old_logs($log);
        $self->store_log($log);
    }
}


sub file_path {
    join '/', $self->plugin_directory, $self->log_file;
}


sub load_log {
    lock_retrieve($self->file_path) if -f $self->file_path;
}


sub store_log {
    lock_store shift, $self->file_path;
}


sub delete_old_logs {
    my $log = shift;

    if ( $self->config->keep_days > 0 ) {
      my $now = time;
      my @to_delete = ();
      foreach (keys %$log) {
          push @to_delete, $_ if ($now - $log->{$_}->[1]) > $self->config->keep_days * $DAY_SECONDS;
      }
      delete $log->{$_} for @to_delete
    }
}


sub date_fmt {
    strftime($self->config->date_format, localtime(shift))
}

1;
__DATA__
=head1 NAME

Kwiki::ReferrerLog - Kwiki ReferrerLog Class

=head1 DESCRIPTION

This module logs all referers coming from external sites to your Kwiki wiki,
and displays them in a convenient, stylable table. That's all. It's very basic
but you can easily redefine/change most of the functionality by overriding the
appropriate methods (see below).

=head1 OPTIONS

=head3 Mandatory

Additionally to the standard installation procedure of a Kwiki::Plugin this
module needs two more options set for functioning correctly.

=over 4

=item

L<site_uri>: This module needs the site_uri parameter configured in your
config.yaml (or what else your config file might be) and set to a correct value.
The value of  the site_uri parameter will be used for sorting out the
internal referrers. So setting this correctly might be of interest to you.

Example: If your Kwiki installation is located at
http://www.example.com/kwiki/index.cgi you should set the site_uri option to
http://www.example.com/kwiki/

=item

L<display_class>: You have to configure the Kwiki::ReferrerLog module as your
plugin for the display-action. This sounds harder than it is.

Simply set add the following line to you config.yaml:
display_class: Kwiki::ReferrerLog

=back

=head3 Optional

The following options can be overriden in your config.yaml file:

=over 4

=item

L<keep_days>: This determines after which number of days, a log entry gets
deleted from the store, if there weren't any requests coming in from that
URL. Don't set this value too high. (default is: 2)

=item

L<date_format>: The date format that is used in the display of logged referrers.
This is directly passed to the L<strftime> function of the L<POSIX> package,
so don't hate me, if you specify a wrong pattern (default is: %d.%m.%Y %H:%M)

=back

=head1 METHODS

The behaviour of the Kwiki::ReferrerLog module can be changed quite easily.
Simply stuff the module in your @ISA array (or use it as a base class) and
override selected methods.
The module provides the following methods, which can be overridden:

=over 4

=item

L<referrerlog()>: This method loads the stored referrers and renders the
template for showing the result back to the browser. It is registered as the
action-method for this module.

=item

L<log_referrer>: This method logs the referrer. For this it checks if the
referrer comes from an external site. If this is not the case, the control
flow leaves the method. Otherwise the stored referrers are loaded and the
current one is appended to the list. Afterwards it checks, if some
of the referrers are older than the configured value for L<keep_days>. If this
is the case, the corresponding referrers are deleted from the list.

=item

L<file_path>: This method returns a relative path to the location of the
referrer log file (default: L<plugin_directory/referrerlog/referrers.log>).

=item

L<load_log>: This method loads the stored referrer entries and returns them as
an hash reference, that contains, keyed by referring URLs, array references.

The following example should clarify the structure:

=begin text
$hashref = { 'http://www.example.com/ref1' =>
                                  [ $visitcount,
                                    $time_of_last_request_via_this_referrer,
                                    $last_uri_that_was_requested_from_this_referrer ]
           }

=end text

=item

L<store_log>: This method takes a hash reference as described above and stores
it, so that the L<load_log> method can retrieve it later.


=item

L<date_fmt>: This method uses the L<date_format> configuration option, to format
the timestamp that is passed as the first and only parameter, as the user/admin
wishes.

=item

L<delete_old_logs>: This method is called before every call to L<store_log>, and
deletes entries, that are older than the number of days specified by the
keep_days option (see above).

=back

=head1 AUTHOR

Benjamin Reitzammer C<cpan@nur-eine-i.de>

=head1 COPYRIGHT

Copyright (c) 2004. Benjamin Reitzammer. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=head1 SEE ALSO

L<POSIX> for strftime date format syntax, L<Storable> is used for referrer
storage

=cut
__config/referrerlog.yaml__
keep_days: 2
date_format: %d.%m.%Y %H:%M
__template/tt2/referrerlog_button.html__
<a href="[% script_name %]?action=referrerlog" title="Log of Referrers">
[% INCLUDE referrerlog_button_icon.html %]
</a>
__template/tt2/referrerlog_button_icon.html__
Referrers
__template/tt2/referrerlog_content.html__
[% IF hub.action == 'referrerlog' %]
  <table id="reflog_table">
    <tr>
      <th class="reflog_head">Viewed Page</th>
      <th class="reflog_head">Referring URL</th>
      <th class="reflog_head">Last Request</th>
      <th class="reflog_head">Count</th>
    </tr>
  [% FOR  ref = log -%]
    <tr>
      <td class="[% 'odd_' IF loop.count % 2 == 0 %]reflog_line">[% ref.uri %]</td>
      <td class="[% 'odd_' IF loop.count % 2 == 0 %]reflog_line">
        <a href="[% ref.refuri %]" title="external link to [% ref.refuri %]">[% ref.refuri %]</a>
        <img src="/images/foreignlinkglyph.png" alt="" border="0" />
      </td>
      <td class="[% 'odd_' IF loop.count % 2 == 0 %]reflog_line">[% self.date_fmt(ref.time) %]</td>
      <td class="[% 'odd_' IF loop.count % 2 == 0 %]reflog_line">[% ref.visitcount %]</td>
    </tr>
  [% END %]
  </table>
[% ELSE %]
  <div class="wiki">
  [% page_html -%]
  </div>
  [% INCLUDE display_changed_by.html %]
[% END %]
__css/referrerlog.css__
#reflog_table { width:100%; }
.reflog_head  {}
.reflog_line      { font-size:8px; font-family:fixed; }
.odd_reflog_line  { font-size:8px; font-family:fixed; background-color:#fffff7; }
