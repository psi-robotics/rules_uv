"uv based pip compile rules"

load("@rules_python//python:defs.bzl", "PyRuntimeInfo")
load(":interpreter_path.bzl", "python_interpreter_path")
load(":transition_to_target.bzl", "transition_to_target")

_PY_TOOLCHAIN = "@bazel_tools//tools/python:toolchain_type"

_DEFAULT_ARGS = [
    "--generate-hashes",
    "--emit-index-url",
    "--no-strip-extras",
]

_COMPILE_ATTRS = {
    "requirements_in": attr.label(mandatory = True, allow_single_file = True),
    "requirements_overrides": attr.label(mandatory = False, allow_single_file = True),
    "requirements_txt": attr.label(mandatory = True, allow_single_file = True),
    "python_platform": attr.string(),
    "universal": attr.bool(),
    "py3_runtime": attr.label(),
    "data": attr.label_list(allow_files = True),
    "uv_args": attr.string_list(default = _DEFAULT_ARGS),
    "extra_args": attr.string_list(),
    "env": attr.string_dict(),
    "generator_label": attr.label(mandatory = True),
    "_uv": attr.label(default = "@multitool//tools/uv", executable = True, cfg = transition_to_target),
}

_UPDATE_ATTRS = {
    "requirements_txt": attr.label(mandatory = True, allow_single_file = True),
    "compiled_requirements": attr.label(mandatory = True, allow_single_file = True),
    "env": attr.string_dict(),
}

def _python_version(py3_runtime):
    # micro is useful when there are some packages that exclude .0 versions due
    # to a bug, such as !=3.11.0
    return "{major}.{minor}.{micro}".format(
        major = py3_runtime.interpreter_version_info.major,
        minor = py3_runtime.interpreter_version_info.minor,
        micro = py3_runtime.interpreter_version_info.micro,
    )

def _python_runtime(ctx):
    if ctx.attr.py3_runtime:
        return ctx.attr.py3_runtime[PyRuntimeInfo]
    py_toolchain = ctx.toolchains[_PY_TOOLCHAIN]
    return py_toolchain.py3_runtime

def _uv_pip_compile_generate_impl(ctx):
    py3_runtime = _python_runtime(ctx)
    compile_command = "bazel run {label}".format(label = str(ctx.attr.generator_label.label))
    output = ctx.outputs.requirements_txt

    args = []
    args += ctx.attr.uv_args
    args += ctx.attr.extra_args
    args.append("--custom-compile-command='{compile_command}'".format(compile_command = compile_command))
    args.append("--python={python}".format(python = python_interpreter_path(py3_runtime)))
    args.append("--python-version={version}".format(version = _python_version(py3_runtime)))
    if ctx.attr.python_platform:
        args.append("--python-platform={platform}".format(platform = ctx.attr.python_platform))
    elif ctx.attr.universal:
        args.append("--universal")
    if ctx.attr.requirements_overrides:
        args.append("--overrides={overrides_file}".format(overrides_file = ctx.file.requirements_overrides.path))

    executable = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        is_executable = True,
        substitutions = {
            "{{uv}}": ctx.executable._uv.path,
            "{{args}}": " \\\n    ".join(args),
            "{{requirements_in}}": ctx.file.requirements_in.path,
            "{{requirements_txt}}": output.path,
        },
    )

    inputs = [ctx.file.requirements_in] + ctx.files.data
    if ctx.attr.requirements_overrides:
        inputs.append(ctx.file.requirements_overrides)

    ctx.actions.run(
        executable = executable,
        inputs = depset(inputs, transitive = [py3_runtime.files]),
        tools = [ctx.executable._uv],
        outputs = [output],
        env = ctx.attr.env,
        mnemonic = "UvPipCompile",
        progress_message = "Generating {output}".format(output = output.short_path),
    )

    return [
        DefaultInfo(files = depset([output])),
    ]

pip_compile = rule(
    attrs = _COMPILE_ATTRS | {
        "_template": attr.label(default = "//uv/private:pip_compile.sh", allow_single_file = True),
    },
    toolchains = [_PY_TOOLCHAIN],
    implementation = _uv_pip_compile_generate_impl,
)

def _runfiles(ctx):
    return ctx.runfiles(
        files = [ctx.file.requirements_txt, ctx.file.compiled_requirements],
    )

def _pip_compile_update_impl(ctx):
    executable = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{compiled_requirements_txt}}": ctx.file.compiled_requirements.short_path,
            "{{requirements_txt_workspace_path}}": ctx.file.requirements_txt.short_path,
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

pip_compile_update = rule(
    attrs = _UPDATE_ATTRS | {
        "_template": attr.label(default = "//uv/private:pip_compile_update.sh", allow_single_file = True),
    },
    implementation = _pip_compile_update_impl,
    executable = True,
)

def _pip_compile_test_impl(ctx):
    executable = ctx.actions.declare_file(ctx.attr.name)
    compile_command = "bazel run {label}".format(label = str(ctx.attr.generator_label.label))
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{compiled_requirements_txt}}": ctx.file.compiled_requirements.short_path,
            "{{requirements_txt_workspace_path}}": ctx.file.requirements_txt.short_path,
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
            # Ensures that .netrc can be detected by uv
            # See https://github.com/theoremlp/rules_uv/issues/103
            inherited_environment = ["HOME", "BUILD_WORKSPACE_DIRECTORY"],
        ),
    ]

pip_compile_test = rule(
    attrs = _UPDATE_ATTRS | {
        "generator_label": attr.label(mandatory = True),
        "_template": attr.label(default = "//uv/private:pip_compile_test.sh", allow_single_file = True),
    },
    implementation = _pip_compile_test_impl,
    test = True,
)
