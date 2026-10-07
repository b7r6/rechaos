"""Canonical client-visible ActionResult fields shared by workload checks."""
import hashlib


def action_observation(reply):
    """Keep output identities and content; discard server execution metadata."""
    def digest(d):
        return f"{d.hash}/{d.size_bytes}"
    def stream(name):
        if reply.HasField(name + "_digest"):
            return digest(getattr(reply, name + "_digest"))
        data = getattr(reply, name + "_raw")
        return f"{hashlib.sha256(data).hexdigest()}/{len(data)}"
    return {
        "exitCode": reply.exit_code,
        "outputDigests": sorted(digest(f.digest) for f in reply.output_files),
        "result": {
            "files": sorted((f.path, digest(f.digest), f.is_executable) for f in reply.output_files),
            "directories": sorted((d.path, digest(d.tree_digest)) for d in reply.output_directories),
            "symlinks": sorted((s.path, s.target) for s in reply.output_symlinks),
            "fileSymlinks": sorted((s.path, s.target) for s in reply.output_file_symlinks),
            "directorySymlinks": sorted((s.path, s.target) for s in reply.output_directory_symlinks),
            "stdout": stream("stdout"), "stderr": stream("stderr"),
        },
    }
