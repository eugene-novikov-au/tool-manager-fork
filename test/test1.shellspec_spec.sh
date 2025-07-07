#!/usr/bin/env tm-env-shellspec

Describe 'lib.sh' # example group
  Describe 'bc command'
    add() { echo "$1 + $2" | bc; }

    It 'performs addition' # example
      When call add 2 3 # evaluation
      The output should eq 5  # expectation
    End
  End
End