Feature: Unicode width recording
  The recorder writes sorted, half-open ranges from the pinned oracle.

  Scenario: Generate a non-default width
    Given the width ranges '[[0,32,0],[127,160,0],[300,301,2]]'
    When I generate the width table
    Then the generated table contains '(300, 301, 2)'

  Scenario Outline: Reject malformed width ranges
    Given the width ranges '<ranges>'
    When I generate the width table
    Then generation fails

    Examples:
      | ranges                 |
      | []                     |
      | [[-1,2,0]]             |
      | [[2,1,0]]              |
      | [[1,2,1]]              |
      | [[0,3,0],[2,4,2]]      |
      | [[0,1114113,2]]        |
      | [[0.5,2,0]]            |
      | [[0,2]]                |
