####################################################################################################################################
# CiTest.pm - Create Travis configuration file for continuous integration testing
####################################################################################################################################
package pgBackRestTest::Common::CiTest;

####################################################################################################################################
# Perl includes
####################################################################################################################################
use strict;
use warnings FATAL => qw(all);
use Carp qw(confess);
use English '-no_match_vars';

use Cwd qw(abs_path);
use Exporter qw(import);
    our @EXPORT = qw();
use File::Basename qw(dirname);
use POSIX qw(ceil);
use Time::HiRes qw(gettimeofday);

use pgBackRest::DbVersion;
use pgBackRest::Common::Exception;
use pgBackRest::Common::Log;
use pgBackRest::Common::String;
use pgBackRest::Version;

use pgBackRestTest::Common::ContainerTest;
use pgBackRestTest::Common::DefineTest;
use pgBackRestTest::Common::ExecuteTest;
use pgBackRestTest::Common::ListTest;
use pgBackRestTest::Common::VmTest;

####################################################################################################################################
# new
####################################################################################################################################
sub new
{
    my $class = shift;          # Class name

    # Create the class hash
    my $self = {};
    bless $self, $class;

    # Assign function parameters, defaults, and log debug info
    (
        my $strOperation,
        $self->{oStorage},
    ) =
        logDebugParam
        (
            __PACKAGE__ . '->new', \@_,
            {name => 'oStorage'},
        );

    # Return from function and log return values if any
    return logDebugReturn
    (
        $strOperation,
        {name => 'self', value => $self, trace => true}
    );
}

####################################################################################################################################
# process
####################################################################################################################################
sub process
{
    my $self = shift;

    # Assign function parameters, defaults, and log debug info
    (my $strOperation) = logDebugParam (__PACKAGE__ . '->process', \@_,);

    # Configure environment
    my $strConfig =
        "branches:\n" .
        "  only:\n" .
        "    - master\n" .
        "    - integration\n" .
        "    - /-ci\$/\n" .
        "\n" .
        "dist: trusty\n" .
        "sudo: required\n" .
        "\n" .
        "language: c\n" .
        "\n" .
        "services:\n" .
        "  - docker\n" .
        "\n" .
        "env:\n";

    my $bFirst = true;

    # Iterate each OS
    foreach my $strVm (VM_LIST)
    {
        $strConfig .=
            "  - PGB_TEST_VM=\"${strVm}\" PGB_TEST_PARAM=\"" . ($bFirst ? '' : " --no-lint") . "\"\n";
        $bFirst = false;
    }

    # Configure install and script
    $strConfig .=
        "\n" .
        "before_install:\n" .
        "  - sudo apt-get -qq update && sudo apt-get install libxml-checker-perl libdbd-pg-perl libperl-critic-perl" .
            " libtemplate-perl libpod-coverage-perl libtest-differences-perl libhtml-parser-perl lintian debhelper txt2man" .
            " devscripts libjson-perl libio-socket-ssl-perl libxml-libxml-perl python-pip\n" .
        "  - |\n" .
        "    # Install & Configure AWS CLI\n" .
        "    pip install --upgrade --user awscli\n" .
        "    aws configure set region us-east-1\n" .
        "    aws configure set aws_access_key_id accessKey1\n" .
        "    aws configure set aws_secret_access_key verySecretKey1\n" .
        "    aws help --version\n" .
        "    aws configure list\n" .
        "  - |\n" .
        "    # Build Devel::Cover\n" .
        "    git clone https://anonscm.debian.org/git/pkg-perl/packages/libdevel-cover-perl.git ~/libdevel-cover-perl\n" .
        '    cd ~/libdevel-cover-perl && git checkout debian/' . LIB_COVER_VERSION . " && debuild -i -us -uc -b\n" .
        '    sudo dpkg -i ~/' . LIB_COVER_PACKAGE . "\n" .
        '    ' . LIB_COVER_EXE . " -v\n" .
        "\n" .
        "install:\n" .
        "  - |\n" .
        "    # User Configuration\n" .
        "    sudo adduser --ingroup=\${USER?} --disabled-password --gecos \"\" " . BACKREST_USER . "\n" .
        "    umask 0022\n" .
        "    cd ~ && pwd && whoami && umask && groups\n" .
        "    mv \${TRAVIS_BUILD_DIR?} " . BACKREST_EXE . "\n" .
        "    rm -rf \${TRAVIS_BUILD_DIR?}\n" .
        "  - " . BACKREST_EXE . "/test/test.pl --vm-build --vm=\${PGB_TEST_VM?}\n" .
        "\n" .
        "script:\n" .
        "  - " . BACKREST_EXE . "/test/test.pl --vm-max=2 --vm-host=u14 --vm=\${PGB_TEST_VM?} \${PGB_TEST_PARAM?}\n";

    $self->{oStorage}->put('.travis.yml', $strConfig);

    # Return from function and log return values if any
    return logDebugReturn($strOperation);
}

1;