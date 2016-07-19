#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.

# Tests for DevStack INI functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import config functions
source $TOP/inc/ini-config

source $TOP/tests/unittest.sh

echo "Testing INI local.conf functions"

# test that can determine if file has section in specified meta-section

function test_localconf_has_section {
    local file_localconf
    local file_conf1
    local file_conf2
    file_localconf=`mktemp`
    file_conf1=`mktemp`
    file_conf2=`mktemp`

    cat <<- EOF > $file_localconf
[[local|localrc]]
LOCALRC_VAR1=localrc_val1
LOCALRC_VAR2=localrc_val2
LOCALRC_VAR3=localrc_val3

[[post-config|$file_conf1]]
[conf1_t1]
conf1_t1_opt1=conf1_t1_val1
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt1=conf2_t1_val1
conf2_t1_opt2=conf2_t1_val2
conf2_t1_opt3=conf2_t1_val3
EOF

    localconf_has_section $file_localconf post-config $file_conf1 conf1_t1
    assert_equal $? 0
    localconf_has_section $file_localconf post-config $file_conf1 conf1_t2
    assert_equal $? 0
    localconf_has_section $file_localconf post-config $file_conf1 conf1_t3
    assert_equal $? 0
    localconf_has_section $file_localconf post-extra $file_conf2 conf2_t1
    assert_equal $? 0
    localconf_has_section $file_localconf post-config $file_conf1 conf1_t4
    assert_equal $? 1
    localconf_has_section $file_localconf post-install $file_conf1 conf1_t1
    assert_equal $? 1
    localconf_has_section $file_localconf local localrc conf1_t2
    assert_equal $? 1
    rm -f $file_localconf $file_conf1 $file_conf2
}

# test that can determine if file has option in specified meta-section and section
function test_localconf_has_option {
    local file_localconf
    local file_conf1
    local file_conf2
    file_localconf=`mktemp`
    file_conf1=`mktemp`
    file_conf2=`mktemp`
    cat <<- EOF > $file_localconf
[[post-config|$file_conf1]]
[conf1_t1]
conf1_t1_opt1 = conf1_t1_val1
conf1_t1_opt2 = conf1_t1_val2
conf1_t1_opt3 = conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[local|localrc]]
LOCALRC_VAR1=localrc_val1
LOCALRC_VAR2=localrc_val2
LOCALRC_VAR3=localrc_val3

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt1=conf2_t1_val1
conf2_t1_opt2=conf2_t1_val2
conf2_t1_opt3=conf2_t1_val3
EOF

    localconf_has_option $file_localconf local localrc "" LOCALRC_VAR1
    assert_equal $? 0
    localconf_has_option $file_localconf local localrc "" LOCALRC_VAR2
    assert_equal $? 0
    localconf_has_option $file_localconf local localrc "" LOCALRC_VAR3
    assert_equal $? 0
    localconf_has_option $file_localconf post-config $file_conf1 conf1_t1 conf1_t1_opt1
    assert_equal $? 0
    localconf_has_option $file_localconf post-config $file_conf1 conf1_t2 conf1_t2_opt2
    assert_equal $? 0
    localconf_has_option $file_localconf post-config $file_conf1 conf1_t3 conf1_t3_opt3
    assert_equal $? 0
    localconf_has_option $file_localconf post-extra $file_conf2 conf2_t1 conf2_t1_opt2
    assert_equal $? 0
    localconf_has_option $file_localconf post-config $file_conf1 conf1_t1_opt4
    assert_equal $? 1
    localconf_has_option $file_localconf post-install $file_conf1 conf1_t1_opt1
    assert_equal $? 1
    localconf_has_option $file_localconf local localrc conf1_t2 conf1_t2_opt1
    assert_equal $? 1
    rm -f $file_localconf $file_conf1 $file_conf2
}

# test that update option in specified meta-section and section
function test_localconf_update_option {
    local file_localconf
    local file_localconf_expected
    local file_conf1
    local file_conf2
    file_localconf=`mktemp`
    file_localconf_expected=`mktemp`
    file_conf1=`mktemp`
    file_conf2=`mktemp`
    cat <<- EOF > $file_localconf
[[local|localrc]]
LOCALRC_VAR1 = localrc_val1
LOCALRC_VAR2 = localrc_val2
LOCALRC_VAR3 = localrc_val3

[[post-config|$file_conf1]]
[conf1_t1]
conf1_t1_opt1=conf1_t1_val1
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt1=conf2_t1_val1
conf2_t1_opt2=conf2_t1_val2
conf2_t1_opt3=conf2_t1_val3
EOF
    cat <<- EOF > $file_localconf_expected
[[local|localrc]]
LOCALRC_VAR1 = localrc_val1
LOCALRC_VAR2 = localrc_val2_update
LOCALRC_VAR3 = localrc_val3

[[post-config|$file_conf1]]
[conf1_t1]
conf1_t1_opt1=conf1_t1_val1_update
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2_update
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3_update

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt1=conf2_t1_val1
conf2_t1_opt2=conf2_t1_val2
conf2_t1_opt3=conf2_t1_val3_update
EOF

    localconf_update_option "$SUDO" $file_localconf local localrc "" LOCALRC_VAR2 localrc_val2_update
    localconf_update_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t1 conf1_t1_opt1 conf1_t1_val1_update
    localconf_update_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t2 conf1_t2_opt2 conf1_t2_val2_update
    localconf_update_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t3 conf1_t3_opt3 conf1_t3_val3_update
    localconf_update_option "$SUDO" $file_localconf post-extra $file_conf2 conf2_t1 conf2_t1_opt3 conf2_t1_val3_update
    result=`cat $file_localconf`
    result_expected=`cat $file_localconf_expected`
    assert_equal "$result" "$result_expected"
    localconf_update_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t2 conf1_t3_opt1 conf1_t3_val1_update
    localconf_update_option "$SUDO" $file_localconf post-extra $file_conf2 conf2_t1 conf2_t1_opt4 conf2_t1_val4_update
    localconf_update_option "$SUDO" $file_localconf post-install $file_conf2 conf2_t1 conf2_t1_opt1 conf2_t1_val1_update
    localconf_update_option "$SUDO" $file_localconf local localrc "" LOCALRC_VAR4 localrc_val4_update
    result=`cat $file_localconf`
    result_expected=`cat $file_localconf_expected`
    assert_equal "$result" "$result_expected"
    rm -f $file_localconf $file_localconf_expected $file_conf1 $file_conf2
}

# test that add option in specified meta-section and section
function test_localconf_add_option {
    local file_localconf
    local file_localconf_expected
    local file_conf1
    local file_conf2
    file_localconf=`mktemp`
    file_localconf_expected=`mktemp`
    file_conf1=`mktemp`
    file_conf2=`mktemp`
    cat <<- EOF > $file_localconf
[[post-config|$file_conf1]]
[conf1_t1]
conf1_t1_opt1=conf1_t1_val1
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[local|localrc]]
LOCALRC_VAR1=localrc_val1
LOCALRC_VAR2=localrc_val2
LOCALRC_VAR3=localrc_val3

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt1 = conf2_t1_val1
conf2_t1_opt2 = conf2_t1_val2
conf2_t1_opt3 = conf2_t1_val3
EOF
    cat <<- EOF > $file_localconf_expected
[[post-config|$file_conf1]]
[conf1_t1]
conf1_t1_opt4 = conf1_t1_val4
conf1_t1_opt1=conf1_t1_val1
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt4 = conf1_t2_val4
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt4 = conf1_t3_val4
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[local|localrc]]
LOCALRC_VAR4 = localrc_val4
LOCALRC_VAR1=localrc_val1
LOCALRC_VAR2=localrc_val2
LOCALRC_VAR3=localrc_val3

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt4 = conf2_t1_val4
conf2_t1_opt1 = conf2_t1_val1
conf2_t1_opt2 = conf2_t1_val2
conf2_t1_opt3 = conf2_t1_val3
EOF

    localconf_add_option "$SUDO" $file_localconf local localrc "" LOCALRC_VAR4 localrc_val4
    localconf_add_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t1 conf1_t1_opt4 conf1_t1_val4
    localconf_add_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t2 conf1_t2_opt4 conf1_t2_val4
    localconf_add_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t3 conf1_t3_opt4 conf1_t3_val4
    localconf_add_option "$SUDO" $file_localconf post-extra $file_conf2 conf2_t1 conf2_t1_opt4 conf2_t1_val4
    result=`cat $file_localconf`
    result_expected=`cat $file_localconf_expected`
    assert_equal "$result" "$result_expected"
    localconf_add_option "$SUDO" $file_localconf local localrc.conf "" LOCALRC_VAR4 localrc_val4_update
    localconf_add_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t4 conf1_t4_opt1 conf1_t4_val1
    localconf_add_option "$SUDO" $file_localconf post-extra $file_conf2 conf2_t2 conf2_t2_opt4 conf2_t2_val4
    localconf_add_option "$SUDO" $file_localconf post-install $file_conf2 conf2_t1 conf2_t1_opt4 conf2_t2_val4
    result=`cat $file_localconf`
    result_expected=`cat $file_localconf_expected`
    assert_equal "$result" "$result_expected"
    rm -f $file_localconf $file_localconf_expected $file_conf1 $file_conf2
}

# test that add section and option in specified meta-section
function test_localconf_add_section_and_option {
    local file_localconf
    local file_localconf_expected
    local file_conf1
    local file_conf2
    file_localconf=`mktemp`
    file_localconf_expected=`mktemp`
    file_conf1=`mktemp`
    file_conf2=`mktemp`
    cat <<- EOF > $file_localconf
[[post-config|$file_conf1]]
[conf1_t1]
conf1_t1_opt1=conf1_t1_val1
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[local|localrc]]
LOCALRC_VAR1=localrc_val1
LOCALRC_VAR2=localrc_val2
LOCALRC_VAR3=localrc_val3

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt1=conf2_t1_val1
conf2_t1_opt2=conf2_t1_val2
conf2_t1_opt3=conf2_t1_val3
EOF
    cat <<- EOF > $file_localconf_expected
[[post-config|$file_conf1]]
[conf1_t4]
conf1_t4_opt1 = conf1_t4_val1
[conf1_t1]
conf1_t1_opt1=conf1_t1_val1
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[local|localrc]]
LOCALRC_VAR1=localrc_val1
LOCALRC_VAR2=localrc_val2
LOCALRC_VAR3=localrc_val3

[[post-extra|$file_conf2]]
[conf2_t2]
conf2_t2_opt1 = conf2_t2_val1
[conf2_t1]
conf2_t1_opt1=conf2_t1_val1
conf2_t1_opt2=conf2_t1_val2
conf2_t1_opt3=conf2_t1_val3
EOF

    localconf_add_section_and_option "$SUDO" $file_localconf post-config $file_conf1 conf1_t4 conf1_t4_opt1 conf1_t4_val1
    localconf_add_section_and_option "$SUDO" $file_localconf post-extra $file_conf2 conf2_t2 conf2_t2_opt1 conf2_t2_val1
    result=`cat $file_localconf`
    result_expected=`cat $file_localconf_expected`
    assert_equal "$result" "$result_expected"
    localconf_add_section_and_option "$SUDO" $file_localconf post-install $file_conf2 conf2_t2 conf2_t2_opt1 conf2_t2_val1
    result=`cat $file_localconf`
    result_expected=`cat $file_localconf_expected`
    assert_equal "$result" "$result_expected"
    rm -f $file_localconf $file_localconf_expected $file_conf1 $file_conf2
}

# test that add section and option in specified meta-section
function test_localconf_set {
    local file_localconf
    local file_localconf_expected
    local file_conf1
    local file_conf2
    file_localconf=`mktemp`
    file_localconf_expected=`mktemp`
    file_conf1=`mktemp`
    file_conf2=`mktemp`
    cat <<- EOF > $file_localconf
[[local|localrc]]
LOCALRC_VAR1=localrc_val1
LOCALRC_VAR2=localrc_val2
LOCALRC_VAR3=localrc_val3

[[post-config|$file_conf1]]
[conf1_t1]
conf1_t1_opt1=conf1_t1_val1
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt1=conf2_t1_val1
conf2_t1_opt2=conf2_t1_val2
conf2_t1_opt3=conf2_t1_val3
EOF
    cat <<- EOF > $file_localconf_expected
[[local|localrc]]
LOCALRC_VAR1=localrc_val1
LOCALRC_VAR2=localrc_val2_update
LOCALRC_VAR3=localrc_val3

[[post-config|$file_conf1]]
[conf1_t4]
conf1_t4_opt1 = conf1_t4_val1
[conf1_t1]
conf1_t1_opt1=conf1_t1_val1
conf1_t1_opt2=conf1_t1_val2
conf1_t1_opt3=conf1_t1_val3
[conf1_t2]
conf1_t2_opt1=conf1_t2_val1
conf1_t2_opt2=conf1_t2_val2
conf1_t2_opt3=conf1_t2_val3
[conf1_t3]
conf1_t3_opt1=conf1_t3_val1
conf1_t3_opt2=conf1_t3_val2
conf1_t3_opt3=conf1_t3_val3

[[post-extra|$file_conf2]]
[conf2_t1]
conf2_t1_opt4 = conf2_t1_val4
conf2_t1_opt1=conf2_t1_val1
conf2_t1_opt2=conf2_t1_val2
conf2_t1_opt3=conf2_t1_val3

[[post-install|/etc/neutron/plugin/ml2/ml2_conf.ini]]
[ml2]
ml2_opt1 = ml2_val1
EOF

    if [[ -n "$SUDO" ]]; then
        SUDO_ARG="-sudo"
    else
        SUDO_ARG=""
    fi
    localconf_set $SUDO_ARG $file_localconf post-install /etc/neutron/plugin/ml2/ml2_conf.ini ml2 ml2_opt1 ml2_val1
    localconf_set $SUDO_ARG $file_localconf local localrc "" LOCALRC_VAR2 localrc_val2_update
    localconf_set $SUDO_ARG $file_localconf post-config $file_conf1 conf1_t4 conf1_t4_opt1 conf1_t4_val1
    localconf_set $SUDO_ARG $file_localconf post-extra $file_conf2 conf2_t1 conf2_t1_opt4 conf2_t1_val4
    result=`cat $file_localconf`
    result_expected=`cat $file_localconf_expected`
    assert_equal "$result" "$result_expected"
    rm -f $file_localconf $file_localconf_expected $file_conf1 $file_conf2
}


test_localconf_has_section
test_localconf_has_option
test_localconf_update_option
test_localconf_add_option
test_localconf_add_section_and_option
test_localconf_set
