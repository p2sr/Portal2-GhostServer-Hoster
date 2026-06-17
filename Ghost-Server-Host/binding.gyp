{
    "targets": [
        {
            "target_name": "addon",
            "sources": ["./main_node.cpp", "./GhostServer/GhostServer/networkmanager.cpp", "./GhostServer/GhostServer/chatcommands.cpp", "./GhostServer/GhostServer/commands.cpp"],
            "libraries": ["-lsfml-network", "-lsfml-system", "-lpthread"],
            "cflags_cc": ["-std=c++17", "-fexceptions"]
        }
    ]
}
