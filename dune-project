(lang dune 3.0)

(generate_opam_files true)

(maintainers "TODO")

(authors "TODO")

(license MIT)

(package
 (name captcha_race)
 (synopsis
  "A single-player race through a gauntlet of captcha mini-games")
 (depends
  (ocaml
   (>= 5.2.0))
  dune
  ocaml-lsp-server
  ocamlformat
  (odoc :with-doc)
  core
  core_unix
  graphics
  ppx_jane
  (expect_test_helpers_core :with-test)))
