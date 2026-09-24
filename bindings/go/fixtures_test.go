package tree_sitter_plato_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	tree_sitter_plato "github.com/ngalaiko/tree-sitter-plato/bindings/go"
	tree_sitter "github.com/tree-sitter/go-tree-sitter"
)

func TestQueriesCompile(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_plato.Language())
	for _, name := range []string{"highlights.scm", "injections.scm"} {
		source, err := os.ReadFile(filepath.Join("..", "..", "queries", name))
		if err != nil {
			t.Fatal(err)
		}
		query, queryErr := tree_sitter.NewQuery(language, string(source))
		if queryErr != nil {
			t.Fatalf("%s: %v", name, queryErr)
		}
		query.Close()
	}
}

func TestReferenceFixtureInventory(t *testing.T) {
	root := filepath.Join("..", "..", "..", "plato", "_fixtures", "input")
	if _, err := os.Stat(root); os.IsNotExist(err) {
		t.Skip("read-only Plato reference checkout is not present")
	}
	parser := tree_sitter.NewParser()
	defer parser.Close()
	if err := parser.SetLanguage(tree_sitter.NewLanguage(tree_sitter_plato.Language())); err != nil {
		t.Fatal(err)
	}
	selected, skipped := 0, 0
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}
		relative, _ := filepath.Rel(root, path)
		suffix := strings.ToLower(relative)
		_, markerErr := os.Stat(path + ".symlink")
		if entry.Type()&os.ModeSymlink != 0 ||
			strings.HasSuffix(suffix, ".gem") || strings.HasSuffix(suffix, ".sops_enc") ||
			strings.HasSuffix(suffix, ".symlink") || markerErr == nil {
			skipped++
			t.Logf("skip %s", relative)
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		selected++
		t.Logf("parse %s", relative)
		tree := parser.Parse(data, nil)
		if tree == nil {
			t.Errorf("%s: parser returned nil", relative)
			return nil
		}
		defer tree.Close()
		if tree.RootNode().HasError() {
			t.Errorf("%s: unexpected ERROR or MISSING node", relative)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("inventory: %d parsed, %d skipped", selected, skipped)
	if selected == 0 || skipped == 0 {
		t.Fatalf("unexpected fixture inventory: %d parsed, %d skipped", selected, skipped)
	}
}
