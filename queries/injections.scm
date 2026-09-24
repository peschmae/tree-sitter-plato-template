((text) @injection.content
 (#plato-host? @injection.content "yaml")
 (#set! injection.language "yaml")
 (#set! injection.combined))

([(text) (yaml_no_injection_text)] @injection.content
 (#plato-host? @injection.content "bash")
 (#set! injection.language "bash")
 (#set! injection.combined))
