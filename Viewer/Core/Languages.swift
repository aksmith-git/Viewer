import Foundation

/// File extension → highlight.js language name.
enum Languages {
    static func language(forExtension ext: String) -> String? { table[ext.lowercased()] }

    private static let table: [String: String] = {
        var t: [String: String] = [:]
        let groups: [String: [String]] = [
            "javascript": ["js", "mjs", "cjs", "jsx"],
            "typescript": ["ts", "tsx", "mts", "cts"],
            "css": ["css"], "scss": ["scss", "sass"], "less": ["less"],
            "xml": ["xml", "plist", "xsd", "xsl", "xslt", "rss", "atom", "storyboard", "xib", "csproj", "vcxproj"],
            "swift": ["swift"], "objectivec": ["m", "mm"], "c": ["c", "h"], "cpp": ["cpp", "cc", "cxx", "hpp", "hh", "hxx", "ino"],
            "csharp": ["cs"], "java": ["java"], "kotlin": ["kt", "kts"], "scala": ["scala", "sc"], "groovy": ["groovy", "gradle"],
            "python": ["py", "pyw", "pyi"], "ruby": ["rb", "rake", "gemspec"], "php": ["php", "phtml"], "perl": ["pl", "pm"],
            "go": ["go"], "rust": ["rs"], "dart": ["dart"], "lua": ["lua"], "r": ["r"], "julia": ["jl"],
            "bash": ["sh", "bash", "zsh", "command", "ksh"], "powershell": ["ps1", "psm1"], "dos": ["bat", "cmd"],
            "sql": ["sql"], "yaml": ["yml", "yaml"], "ini": ["ini", "toml", "cfg", "conf", "properties", "editorconfig"],
            "makefile": ["mk", "mak"], "cmake": ["cmake"], "dockerfile": ["dockerfile"], "diff": ["diff", "patch"],
            "haskell": ["hs"], "elixir": ["ex", "exs"], "erlang": ["erl", "hrl"], "clojure": ["clj", "cljs", "edn"],
            "fsharp": ["fs", "fsx"], "ocaml": ["ml", "mli"], "vbnet": ["vb"], "matlab": ["matlab"], "fortran": ["f90", "f95", "for"],
            "x86asm": ["asm", "s"], "latex": ["tex", "sty", "cls"], "graphql": ["graphql", "gql"], "protobuf": ["proto"],
            "vim": ["vim"], "nginx": ["nginx"], "apache": ["htaccess"], "wasm": ["wat"], "glsl": ["glsl", "vert", "frag"],
            "plaintext": ["log", "gitignore", "env"],
        ]
        for (lang, exts) in groups { for e in exts { t[e] = lang } }
        return t
    }()
}
