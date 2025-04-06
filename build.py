import os
import sys
import lzma
import base64
import struct
import io
import time

class GMAWriter:
    HEADER = b"GMAD"
    VERSION = 3

    def __init__(self, name, steam_id64):
        self.name = name
        self.steam_id64 = steam_id64
        self.author = "unknown"
        self.description = ""
        self.entries = []

    def add_file(self, name, content):
        self.entries.append({"name": name, "content": content})

    @staticmethod
    def _write_c_string(f, s):
        if "\0" in s:
            raise ValueError("String contains null byte")
        f.write(s.encode("utf-8") + b"\x00")

    def get_data(self):
        buffer = io.BytesIO()
        buffer.write(self.HEADER)
        buffer.write(struct.pack("B", self.VERSION))
        buffer.write(struct.pack("<Q", self.steam_id64))
        buffer.write(struct.pack("<Q", int(time.time())))
        buffer.write(b"\x00")
        self._write_c_string(buffer, self.name)
        self._write_c_string(buffer, self.description)
        self._write_c_string(buffer, self.author)
        buffer.write(struct.pack("<i", 1))
        for i, e in enumerate(self.entries, start=1):
            buffer.write(struct.pack("<I", i))
            self._write_c_string(buffer, e["name"])
            buffer.write(struct.pack("<Q", len(e["content"])))
            buffer.write(struct.pack("<I", 0))
        buffer.write(struct.pack("<I", 0))
        for e in self.entries:
            buffer.write(e["content"])
        buffer.write(struct.pack("<I", 0))
        return buffer.getvalue()

def main():
    os.system("build_shaders.bat")

    version = str(int(time.time()))
    writer = GMAWriter(f"RNDX_{version}", 12345678901234567)

    # Directory containing the shaders to be compiled.
    shaders_dir = os.path.join("src", "shaders", "fxc")
    if not os.path.exists(shaders_dir):
        print(f"Error: The directory '{shaders_dir}' does not exist.")
        sys.exit(1)

    for filename in os.listdir(shaders_dir):
        file_path = os.path.join(shaders_dir, filename)
        if os.path.isfile(file_path):
            with open(file_path, "rb") as file:
                content = file.read()
            # Prefix the filename with the Unix timestamp version.
            new_filename = f"shaders/fxc/{version}_{filename}"
            writer.add_file(new_filename, content)

    binary_data = writer.get_data()

    b64_encoded_data = base64.b64encode(binary_data).decode("utf-8")

    # Load and modify the src/rndx.lua file by replacing placeholders.
    rndx_path = os.path.join("src", "rndx.lua")
    if not os.path.exists(rndx_path):
        print(f"Error: The file '{rndx_path}' does not exist.")
        sys.exit(1)

    with open(rndx_path, "r", encoding="utf-8") as f:
        lua_content = f.read()

    lua_content = lua_content.replace("SHADERS_VERSION_PLACEHOLDER", version)
    lua_content = lua_content.replace("SHADERS_GMA_PLACEHOLDER", b64_encoded_data)

    # Write the updated content back to the file.
    with open(rndx_path, "w", encoding="utf-8") as f:
        f.write(lua_content)

    print("Processing complete.")

if __name__ == "__main__":
    main()
