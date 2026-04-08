# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    minimize: 1,
    maximize: 1,
    subject_to: 1,
    subject_to: 2,
    for_each: 2,
    for_each: 3,
    add_to_objective: 1
  ],
  export: [
    locals_without_parens: [
      minimize: 1,
      maximize: 1,
      subject_to: 1,
      subject_to: 2,
      for_each: 2,
      for_each: 3,
      add_to_objective: 1
    ]
  ]
]
