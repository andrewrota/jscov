function trailing_semicolon() {
  return 1
  ;
}


;(
  // Comment between
  function() {}
);

;(
  // Comment between
  f()+g()
);
