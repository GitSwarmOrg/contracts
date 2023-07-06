import os


def upgrade_contracts(from_version, to_version):
    upgrade_func_name = "upgrade_from_%s_to_%s" % (from_version.replace('.', '_'), to_version.replace('.', '_'))

    if upgrade_func_name not in globals():
        raise ValueError("Upgrade function not defined from version %s to version %s" % (from_version, to_version))

    upgrade_func = globals()[upgrade_func_name]
    upgrade_func()


def get_contracts_versions_list():
    path_to_versions = "contracts/prod/"
    return [name for name in os.listdir(path_to_versions) if os.path.isdir(path_to_versions + name)]
