#!/usr/bin/env bash

# Tests for DevStack vercmp functionality

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions
source $TOP/tests/unittest.sh

assert_true "numeric gt"  vercmp 2.0 ">" 1.0
assert_true "numeric gte" vercmp 2.0 ">=" 1.0
assert_true "numeric gt"  vercmp 1.0.1 ">" 1.0
assert_true "numeric gte" vercmp 1.0.1 ">=" 1.0
assert_true "alpha gt"    vercmp 1.0.1b ">" 1.0.1a
assert_true "alpha gte"   vercmp 1.0.1b ">=" 1.0.1a
assert_true "alpha gt"    vercmp b ">" a
assert_true "alpha gte"   vercmp b ">=" a
assert_true "alpha gt"    vercmp 2.0-rc3 ">" 2.0-rc1
assert_true "alpha gte"   vercmp 2.0-rc3 ">=" 2.0-rc1

assert_false "numeric gt fail"  vercmp 1.0 ">" 1.0
assert_true  "numeric gte"      vercmp 1.0 ">=" 1.0
assert_false "numeric gt fail"  vercmp 0.9 ">" 1.0
assert_false "numeric gte fail" vercmp 0.9 ">=" 1.0
assert_false "numeric gt fail"  vercmp 0.9.9 ">" 1.0
assert_false "numeric gte fail" vercmp 0.9.9 ">=" 1.0
assert_false "numeric gt fail"  vercmp 0.9a.9 ">" 1.0.1
assert_false "numeric gte fail" vercmp 0.9a.9 ">=" 1.0.1

assert_false "numeric lt"  vercmp 1.0 "<" 1.0
assert_true  "numeric lte" vercmp 1.0 "<=" 1.0
assert_true "numeric lt"   vercmp 1.0 "<" 1.0.1
assert_true "numeric lte"  vercmp 1.0 "<=" 1.0.1
assert_true "alpha lt"     vercmp 1.0.1a "<" 1.0.1b
assert_true "alpha lte"    vercmp 1.0.1a "<=" 1.0.1b
assert_true "alpha lt"     vercmp a "<" b
assert_true "alpha lte"    vercmp a "<=" b
assert_true "alpha lt"     vercmp 2.0-rc1 "<" 2.0-rc3
assert_true "alpha lte"    vercmp 2.0-rc1 "<=" 2.0-rc3

assert_true "eq"       vercmp 1.0 "==" 1.0
assert_true "eq"       vercmp 1.0.1 "==" 1.0.1
assert_false "eq fail" vercmp 1.0.1 "==" 1.0.2
assert_false "eq fail" vercmp 2.0-rc1 "==" 2.0-rc2

report_results
