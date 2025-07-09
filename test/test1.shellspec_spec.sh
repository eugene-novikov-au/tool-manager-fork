#!/usr/bin/env env-tm-shellspec

Describe 'lib.sh' # example group
  Describe 'string concat'
    add() { echo "$1$2"; }

    It 'performs addition' # example
      When call add 2 3 # evaluation
      The output should eq '23'  # expectation
    End
  End
End