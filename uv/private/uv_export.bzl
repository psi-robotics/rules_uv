"uv based pip lock rules"

load("@rules_python//python:defs.bzl", "PyRuntimeInfo")
load(":interpreter_path.bzl", "python_interpreter_path")
load(":transition_to_target.bzl", "transition_to_target")

_PY_TOOLCHAIN = "@bazel_tools//tools/python:toolchain_type"

# uv export has different defaults than uv pip compile
_DEFAULT_ARGS = [
    "--format",
    "requirements.txt",
    "--no-header",  # Exclude the header comment with uv command that generated the file
    "--no-emit-workspace",  # Don't emit any workspace structure in the output
]

_COMPILE_ATTRS = {
    "pyproject_toml": attr.label(mandatory = True, allow_single_file = True),
    "requirements_txt": attr.output(mandatory = True),
    "uv_lock": attr.output(mandatory = True),
    "py3_runtime": attr.label(),
    "data": attr.label_list(allow_files = True),
    "uv_args": attr.string_list(default = _DEFAULT_ARGS),
    "common_args": attr.string_list(),
    "export_args": attr.string_list(),
    "lock_args": attr.string_list(),
    "env": attr.string_dict(),
    "generator_label": attr.label(mandatory = True),
    "_template": attr.label(default = "//uv/private:uv_export.sh", allow_single_file = True),
    "_uv": attr.label(default = "@multitool//tools/uv", executable = True, cfg = transition_to_target),
}

_UPDATE_ATTRS = {
    "requirements_txt": attr.label(mandatory = True, allow_single_file = True),
    "uv_lock": attr.label(mandatory = True, allow_single_file = True),
    "generated_requirements_txt": attr.label(mandatory = True, allow_single_file = True),
    "generated_uv_lock": attr.label(mandatory = True, allow_single_file = True),
    "env": attr.string_dict(),
}

def _python_runtime(ctx):
    if ctx.attr.py3_runtime:
        return ctx.attr.py3_runtime[PyRuntimeInfo]
    py_toolchain = ctx.toolchains[_PY_TOOLCHAIN]
    return py_toolchain.py3_runtime

def _uv_export_compile_impl(ctx):
    py3_runtime = _python_runtime(ctx)
    compile_command = "bazel run {label}".format(label = str(ctx.attr.generator_label.label))
    python_arg = "--python={python}".format(python = python_interpreter_path(py3_runtime))
    export_args = ctx.attr.uv_args + ctx.attr.common_args + ctx.attr.export_args + [python_arg]
    lock_args = ctx.attr.lock_args + ctx.attr.common_args + [python_arg]

    inputs = [ctx.file.pyproject_toml] + ctx.files.data
    input_files = [ctx.file.pyproject_toml.short_path] + [f.short_path for f in ctx.files.data]

    command_script = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = command_script,
        is_executable = True,
        substitutions = {
            "{{uv}}": ctx.executable._uv.path,
            "{{pyproject_toml}}": ctx.file.pyproject_toml.short_path,
            "{{requirements_txt}}": ctx.outputs.requirements_txt.path,
            "{{uv_lock}}": ctx.outputs.uv_lock.path,
            "{{compile_command}}": compile_command,
            "{{export_args}}": " \\\n    ".join(export_args),
            "{{lock_args}}": " \\\n    ".join(lock_args),
            "{{input_files}}": "\n".join(["    '{}'".format(path) for path in input_files]),
        },
    )

    ctx.actions.run(
        executable = command_script,
        inputs = depset(inputs, transitive = [py3_runtime.files]),
        tools = [ctx.executable._uv],
        outputs = [ctx.outputs.requirements_txt, ctx.outputs.uv_lock],
        env = ctx.attr.env,
        mnemonic = "UvExport",
        progress_message = "Generating {output}".format(output = ctx.outputs.requirements_txt.short_path),
    )

    return [
        DefaultInfo(files = depset([ctx.outputs.requirements_txt, ctx.outputs.uv_lock])),
    ]

uv_export = rule(
    attrs = _COMPILE_ATTRS,
    toolchains = [_PY_TOOLCHAIN],
    implementation = _uv_export_compile_impl,
)

def _runfiles(ctx):
    return ctx.runfiles(
        files = [
            ctx.file.requirements_txt,
            ctx.file.uv_lock,
            ctx.file.generated_requirements_txt,
            ctx.file.generated_uv_lock,
        ],
    )

def _uv_export_impl(ctx):
    executable = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{generated_requirements_txt}}": ctx.file.generated_requirements_txt.short_path,
            "{{generated_uv_lock}}": ctx.file.generated_uv_lock.short_path,
            "{{requirements_txt_workspace_path}}": ctx.file.requirements_txt.short_path,
            "{{uv_lock_workspace_path}}": ctx.file.uv_lock.short_path,
        },
    )
    return [
        DefaultInfo(
            executable = executable,
            runfiles = _runfiles(ctx),
        ),
        RunEnvironmentInfo(
            environment = ctx.attr.env,
        ),
    ]

uv_export_update = rule(
    attrs = _UPDATE_ATTRS | {
        "_template": attr.label(default = "//uv/private:uv_export_update.sh", allow_single_file = True),
    },
    implementation = _uv_export_impl,
    executable = True,
)

def _uv_export_test_impl(ctx):
    executable = ctx.actions.declare_file(ctx.attr.name)
    compile_command = "bazel run {label}".format(label = str(ctx.attr.generator_label.label))
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{generated_requirements_txt}}": ctx.file.generated_requirements_txt.short_path,
            "{{generated_uv_lock}}": ctx.file.generated_uv_lock.short_path,
            "{{requirements_txt_workspace_path}}": ctx.file.requirements_txt.short_path,
            "{{uv_lock_workspace_path}}": ctx.file.uv_lock.short_path,
            "{{compile_command}}": compile_command,
        },
    )
    return [
        DefaultInfo(
            executable = executable,
            runfiles = _runfiles(ctx),
        ),
        RunEnvironmentInfo(
            environment = ctx.attr.env,
            inherited_environment = ["HOME", "BUILD_WORKSPACE_DIRECTORY"],
        ),
    ]

uv_export_test = rule(
    attrs = _UPDATE_ATTRS | {
        "generator_label": attr.label(mandatory = True),
        "_template": attr.label(default = "//uv/private:uv_export_test.sh", allow_single_file = True),
    },
    implementation = _uv_export_test_impl,
    test = True,
)
