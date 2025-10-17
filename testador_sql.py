import os
import sys
import pyodbc
import pandas as pd
from dotenv import load_dotenv
import glob
import tkinter as tk
from tkinter import ttk
from tkinter import messagebox
import shutil  # Adicionado para compactação
import datetime  # Adicionado para o nome do arquivo ZIP

# --- FUNÇÃO AUXILIAR PARA PORTABILIDADE ---


def resource_path(relative_path):
    """ Obtém o caminho absoluto para o recurso, funciona para dev e para PyInstaller """
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)


# --- 1. CONFIGURAÇÕES E CREDENCIAIS ---
print("Carregando configuracoes...")
load_dotenv()
username = os.getenv('DB_USERNAME')
password = os.getenv('DB_PASSWORD')

# --- NOVA FORMA DE DEFINIR O CAMINHO DO CERTIFICADO ---
print("Definindo caminho do certificado...")
try:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cert_path = os.path.join(script_dir, "Certificados", "cacerts.pem")
    print(f"   - Caminho do certificado definido para: {cert_path}")
    if not os.path.exists(cert_path):
        print(
            "   - [ATENCAO] O arquivo do certificado nao foi encontrado no caminho especificado.")
except NameError:
    script_dir = os.path.abspath(".")
    cert_path = os.path.join(script_dir, "Certificados", "cacerts.pem")
    print(f"   - Caminho do certificado (fallback) definido para: {cert_path}")

# --- 2. FUNÇÃO DE CONEXÃO E CONSULTA (VERSÃO ROBUSTA) ---


def fetch_data_from_impala_robust(sql_query, user, pwd):
    conn = None
    cursor = None
    print("   - [MODO ROBUSTO] Iniciando conexao com cursor...")

    # Removida a linha "TrustedCerts" para usar a configuração do sistema
    connection_string = (
        f"Driver={{Cloudera ODBC Driver for Impala}};"
        f"Host=dlmg.prodemge.gov.br;"
        f"Port=21051;"
        f"AuthMech=3;"
        f"UID={user};"
        f"PWD={pwd};"
        f"TransportMode=sasl;"
        f"KrbServiceName=impala;"
        f"SSL=1;"
        f"AllowSelfSignedServerCert=1;"
        f"AutoReconnect=1;"
        f"UseSQLUnicode=1;"
    )

    try:
        conn = pyodbc.connect(connection_string, autocommit=True)
        print("   - Conexao estabelecida.")
        cursor = conn.cursor()
        print("   - Cursor criado. Executando a consulta SQL...")
        cursor.execute(sql_query)
        print("   - Consulta executada com sucesso no banco.")

        if cursor.description:
            results = cursor.fetchall()
            print(f"   - {len(results)} registros recebidos do banco.")
            columns = [column[0] for column in cursor.description]
            df = pd.DataFrame.from_records(results, columns=columns)
            print("   - DataFrame criado a partir dos resultados.")
        else:
            df = pd.DataFrame()
            print("   - A consulta nao retornou resultados ou colunas.")
        return df
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        print("   - Conexao e cursor fechados.")

# --- NOVA FUNÇÃO PARA COMPACTAR A PASTA ---


def zip_folder(folder_path, output_parent_dir):
    """Compacta uma pasta e salva no diretório pai com timestamp."""
    if not os.path.isdir(folder_path):
        print(f"\n[ERRO] A pasta a ser compactada nao existe: {folder_path}")
        return

    print(f"\n-> Iniciando compactacao da pasta: {folder_path}")
    try:
        folder_name = os.path.basename(folder_path)
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        output_filename = f"{folder_name}_{timestamp}"

        archive_path = os.path.join(output_parent_dir, output_filename)

        shutil.make_archive(archive_path, 'zip', folder_path)

        print(f"   - Arquivo ZIP criado com sucesso em: {archive_path}.zip ✅")
    except Exception as e:
        print(f"\n[ERRO] Falha ao criar o arquivo ZIP: {e}")

# --- 3. FUNÇÃO PARA SELECIONAR ARQUIVOS SQL COM TKINTER (MODIFICADA) ---


# Substitua a sua função antiga por esta nova versão
def selecionar_arquivos_gui(sql_path):
    selected_files = []
    user_action = None  # Variável para guardar a ação do usuário

    root = tk.Tk()
    root.title("Seletor de Scripts SQL")
    root.geometry("600x450")  # Aumentei um pouco a largura inicial
    root.minsize(500, 350)     # Defini um tamanho mínimo

    # Frame principal com padding
    main_frame = ttk.Frame(root, padding="10")
    main_frame.pack(fill=tk.BOTH, expand=True)

    # --- Área Superior: Título ---
    label = ttk.Label(main_frame, text="Selecione os arquivos SQL para processar:", font=(
        "Segoe UI", 10, "bold"))
    label.pack(fill=tk.X, pady=(0, 5))

    # --- Área Central: Lista de Arquivos com Scroll ---
    list_frame = ttk.Frame(main_frame)
    list_frame.pack(fill=tk.BOTH, expand=True)

    canvas = tk.Canvas(list_frame)
    scrollbar = ttk.Scrollbar(
        list_frame, orient="vertical", command=canvas.yview)
    scrollable_frame = ttk.Frame(canvas, padding=(5, 0))
    scrollable_frame.bind("<Configure>", lambda e: canvas.configure(
        scrollregion=canvas.bbox("all")))

    canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
    canvas.configure(yscrollcommand=scrollbar.set)

    # Ordem dos .pack() é importante para o layout da scrollbar
    scrollbar.pack(side="right", fill="y")
    canvas.pack(side="left", fill="both", expand=True)

    check_vars = []
    all_files = sorted(glob.glob(os.path.join(sql_path, '*.sql')))
    for file_path in all_files:
        var = tk.BooleanVar()
        chk = ttk.Checkbutton(
            scrollable_frame, text=os.path.basename(file_path), variable=var)
        # Adicionado pady para espaçar a lista
        chk.pack(anchor='w', padx=5, pady=2)
        check_vars.append((var, file_path))

    # --- Separador Visual ---
    separator = ttk.Separator(main_frame, orient='horizontal')
    separator.pack(fill='x', pady=10)

    # --- Área Inferior: Controles ---
    control_frame = ttk.Frame(main_frame)
    control_frame.pack(fill='x')

    # Configura o grid para que as 3 colunas dos botões se expandam igualmente
    control_frame.columnconfigure((0, 1, 2), weight=1)

    # Checkbox "Marcar Todos" na primeira linha do grid, alinhado à esquerda
    def toggle_all():
        new_state = select_all_var.get()
        for var, _ in check_vars:
            var.set(new_state)

    select_all_var = tk.BooleanVar()
    select_all_check = ttk.Checkbutton(
        control_frame, text="Marcar/Desmarcar Todos", variable=select_all_var, command=toggle_all)
    select_all_check.grid(row=0, column=0, columnspan=3,
                          sticky='w', pady=(0, 10))

    # Funções para definir a ação do usuário
    def handle_action(action):
        nonlocal selected_files, user_action
        selected_files = [file_path for var,
                          file_path in check_vars if var.get()]
        user_action = action

        if not selected_files and action in ['process', 'process_and_zip']:
            messagebox.showwarning(
                "Aviso", "Nenhum arquivo foi selecionado para processar!")
            return

        root.destroy()

    # Botões de ação na segunda linha do grid
    process_button = ttk.Button(
        control_frame, text="Processar Selecionados", command=lambda: handle_action('process'))
    process_button.grid(row=1, column=0, sticky=tk.EW, padx=(0, 5))

    process_zip_button = ttk.Button(
        control_frame, text="Processar e Compactar (ZIP)", command=lambda: handle_action('process_and_zip'))
    process_zip_button.grid(row=1, column=1, sticky=tk.EW, padx=5)

    zip_only_button = ttk.Button(
        control_frame, text="Apenas Compactar (ZIP)", command=lambda: handle_action('zip_only'))
    zip_only_button.grid(row=1, column=2, sticky=tk.EW, padx=(5, 0))

    root.mainloop()
    return selected_files, user_action


# --- 4. EXECUÇÃO PRINCIPAL (MODIFICADA) ---
if __name__ == "__main__":
    if not username or not password:
        print("\n[ERRO CRITICO] Variaveis DB_USERNAME e DB_PASSWORD nao encontradas.")
        input("\nPressione ENTER para fechar...")
        sys.exit()

    base_path = r"E:\GDO_RURAL_MAMB"
    sql_scripts_path = os.path.join(base_path, "sql_scripts")
    output_csv_path = os.path.join(base_path, "csv")

    os.makedirs(output_csv_path, exist_ok=True)

    sql_files_to_process, action = selecionar_arquivos_gui(sql_scripts_path)

    if not action:
        print("\nNenhuma ação selecionada. Encerrando o programa.")
        sys.exit()

    # Decide se vai processar os arquivos SQL
    if action in ['process', 'process_and_zip']:
        print(
            f"\nIniciando processamento de {len(sql_files_to_process)} arquivo(s) selecionado(s)...")
        for sql_file_path in sql_files_to_process:
            result_df = None
            try:
                print(
                    f"\n-> Processando arquivo: {os.path.basename(sql_file_path)}")
                with open(sql_file_path, 'r', encoding='utf-8') as f:
                    query = f.read()
                cleaned_query = query.strip().rstrip(';')
                print("    - Query lida e limpa (removido ';' final).")
                result_df = fetch_data_from_impala_robust(
                    cleaned_query, username, password)
            except Exception as e:
                print("\n" + "#" * 50)
                print("########## ERRO INESPERADO AO PROCESSAR ARQUIVO ##########")
                print(
                    f"Ocorreu uma falha ao tentar processar o arquivo: {os.path.basename(sql_file_path)}")
                print(f"\n[!] TIPO DE EXCECAO: {type(e)}")
                print(f"[!] ARGUMENTOS DO ERRO (mensagem original): {e.args}")
                print("#" * 50)
                continue

            if result_df is not None:
                if result_df.empty:
                    print(
                        "\n[AVISO] A consulta foi executada com sucesso, mas nao retornou nenhum dado. Nenhum arquivo sera salvo.")
                else:
                    try:
                        base_filename = os.path.splitext(
                            os.path.basename(sql_file_path))[0]
                        output_filename = f"{base_filename}.csv"
                        output_filepath = os.path.join(
                            output_csv_path, output_filename)
                        print(f"\n-> Salvando resultado em: {output_filepath}")
                        result_df.to_csv(
                            output_filepath, index=False, sep=';', encoding='utf-8-sig')
                        print("   - Arquivo salvo com sucesso! ✅")
                    except Exception as e:
                        print(f"\n[ERRO] Falha ao salvar o arquivo CSV: {e}")

    # Decide se vai compactar a pasta
    if action in ['process_and_zip', 'zip_only']:
        zip_folder(output_csv_path, base_path)

    input("\nProcesso finalizado. Pressione ENTER para fechar...")
