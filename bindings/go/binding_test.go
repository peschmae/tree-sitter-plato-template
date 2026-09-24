package tree_sitter_plato_test

import (
	"testing"

	tree_sitter_plato "github.com/ngalaiko/tree-sitter-plato/bindings/go"
	tree_sitter "github.com/tree-sitter/go-tree-sitter"
)

func TestGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_plato.Language())
	if language == nil {
		t.Fatal("Error loading plato grammar")
	}

	parser := tree_sitter.NewParser()
	defer parser.Close()
	if err := parser.SetLanguage(language); err != nil {
		t.Fatal(err)
	}

	tree := parser.Parse([]byte("{{{ nil }}}"), nil)
	if tree == nil {
		t.Errorf("Error parsing code")
	}
	defer tree.Close()

	root := tree.RootNode()
	if root == nil {
		t.Errorf("Error parsing code")
	}

	if root.ToSexp() != "(template (nil))" {
		t.Errorf("Unexpected tree: %s", root.ToSexp())
	}
}

func TestLiteralBracesAndCRLF(t *testing.T) {
	parser := tree_sitter.NewParser()
	defer parser.Close()
	if err := parser.SetLanguage(tree_sitter.NewLanguage(tree_sitter_plato.Language())); err != nil {
		t.Fatal(err)
	}
	for _, source := range []string{
		"é: {{ literal\r\nname: {{{ .Name }}}\r\n",
		"echo '${HOME}' '{{{printf \"%s\" \"}}} quoted\"}}}'\r\n",
	} {
		tree := parser.Parse([]byte(source), nil)
		if tree == nil {
			t.Fatal("parser returned nil")
		}
		if tree.RootNode().HasError() {
			t.Error("unexpected syntax error in synthetic UTF-8/CRLF template")
		}
		tree.Close()
	}
}
