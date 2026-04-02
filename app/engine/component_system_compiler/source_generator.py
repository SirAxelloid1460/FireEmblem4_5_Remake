from app.engine.component_system_compiler.compile_item_system import compile_item_system
from app.engine.component_system_compiler.compile_skill_system import compile_skill_system

def generate_component_system_source():
    compile_skill_system()
    compile_item_system()

if __name__ == '__main__':
    generate_component_system_source()
