# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>
#
# The Initial Developer of the Original Code is Nokia. Portions created by the
# Initial Developer are Copyright (C) 2012 Nokia. All Rights Reserved.
#
# Contributor(s):
#   David Wilson <ext-david.3.wilson@nokia.com>

package Bugzilla::Extension::BayotBase;

use strict;
use JSON;
use base qw(Bugzilla::Extension);

our $VERSION = '0.01';


# Invoke the bb_common_links hook, aggregating returned menu items into a
# bb_common_links variable, for hook/global/common-links-link-row.html.tmpl
sub build_common_links {
    my ($args, $vars, $file) = @_;

    my %links;
    Bugzilla::Hook::process('bb_common_links', {
        args => $args,
        vars => $vars,
        file => $file,
        links => \%links
    });

    my @items;
    while(my ($section, $section_items) = each(%links)) {
        push @items, @$section_items;
    }

    $vars->{bb_common_links} = [ sort
        { ($a->{priority} || 999) <=> ($b->{priority} || 999)
            or ($a->{text} cmp $b->{text}) } @items
    ];
}


# Create a JSON object containing various useful Bugzilla runtime information.
sub make_bb_config {
    my ($args, $vars, $file) = @_;

    my $config = {};
    if(Bugzilla->user->id) {
        $config->{user} = {
            logged_in => JSON::true,
            login => Bugzilla->user->login,
            email => Bugzilla->user->email,
            id => Bugzilla->user->id,
            groups => [ sort map { $_->{name} } @{Bugzilla->user->groups} ]
        };
    } else {
        $config->{user} = {
            logged_in => JSON::false
        };
    }
    $config->{default} = {
        bugentry_fields => [split(/\s/,
            Bugzilla->params->{'bb_bug_entry_fields'})],
        priority => Bugzilla->params->{'defaultpriority'},
        severity => Bugzilla->params->{'defaultseverity'},
        platform => Bugzilla->params->{'defaultplatform'},
        op_sys => Bugzilla->params->{'defaultopsys'},
    };

    $vars->{bb_config} = JSON->new->utf8->encode($config);
}


sub template_before_process {
    my ($self, $args) = @_;

    my $vars = $args->{vars};
    my $file = $args->{file};

    build_common_links($args, $vars, $file);
    make_bb_config($args, $vars, $file);
}

sub template_before_create {
    my ($self, $params) = @_;
    # TODO: document remove_query_param template filter
    $params->{config}->{FILTERS}->{remove_query_param} = [
        sub {
            my ($context, @args) = @_;
            return sub {
                my $query = shift;
                my ($param) = @args;
                my @parts = grep($_ !~ /^$param=/, split('&', $query));
                return join('&', @parts);
            }
        }, 1
    ];
}

sub config_add_panels {
    my ($self, $args) = @_;
    my $modules = $args->{panel_modules};
    $modules->{BayotBase} = "Bugzilla::Extension::BayotBase::Config";
}


sub webservice {
    my ($self, $args) = @_;
    $args->{dispatch}->{'BayotBase'} =
        "Bugzilla::Extension::BayotBase::WebService";
}
__PACKAGE__->NAME;
