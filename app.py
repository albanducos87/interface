from flask import Flask, render_template, redirect, url_for, request
import requests
import random
import tensorflow as tf

app = Flask(__name__)
infoConso = ""
select_model_name = "-- Veuillez choisir un outil --"
is_selected = False
contenu = ""
devices_json = "all_devices.json"
category_selected = False
selected_category_name = ""
array_devices = []
array_details = []
gwp_details = []
pe_details = []
adp_details = []
size = 0
colors = []

@app.route("/")
def main():
    global contenu
    contenu = getDevices()
    return render_template("index.html", contenu=contenu, infoConso=infoConso, selected_model_name=select_model_name, is_selected=is_selected)

@app.route("/get_conso_model/<select_model>", methods=['GET'])
def getConso(select_model):
    global infoConso
    global is_selected
    global select_model_name
    is_selected = True
    select_model_name = select_model
    infoConso = getConsoByDevice(select_model)
    return redirect(url_for('main'))

@app.route("/reset_info_conso")
def reset():
    global select_model_name
    global infoConso
    global is_selected
    select_model_name = "-- Veuillez choisir un outil --"
    infoConso = ""
    is_selected = False
    return redirect(url_for('main'))

@app.route("/all_devices")
def all_devices():
    array_global_devices = getDevices()
    listCat = makeCategories(array_global_devices)
    if (category_selected):
        get_conso_by_cat(selected_category_name)

    return render_template("all_devices.html", cat_name = selected_category_name,categories=listCat, category_selected=category_selected, array_devices=array_devices, array_details=array_details, gwp_details=gwp_details, pe_details=pe_details, adp_details=adp_details, size = size, colors=colors)

@app.route('/devices_by_cat/<category>', methods=['GET'])
def get_conso_by_cat(category):
    global category_selected
    global array_devices
    global array_details
    global gwp_details
    global pe_details
    global adp_details
    global size
    global colors
    global selected_category_name
    selected_category_name = category

    category_selected = True
    array_devices = []
    array_devices = get_devices_by_cat(category)
    array_details = []
    gwp_details = []
    pe_details = []
    adp_details = []
    for d in range(len(array_devices)):
        array_details.append(getConsoByDevice(array_devices[d]))
        gwp_details.append(array_details[d]["gwp"]["manufacture"])
        pe_details.append(array_details[d]["pe"]["manufacture"])
        adp_details.append(array_details[d]["adp"]["manufacture"])
    
    colors = []
    for d in range(len(array_devices)):
        rColor = [int(random.uniform(1,255)), int(random.uniform(1,255)), int(random.uniform(1,255)),0.5]
        colors.append(rColor)
    size = len(array_devices)
    
    return redirect(url_for('all_devices'))

def get_devices_by_cat(category):
    array_devices = getDevices()
    array_devices_cat = []
    for c in array_devices:
        if (c[0:2] == category):
            array_devices_cat.append(c)
    return array_devices_cat

@app.route('/my_instances', methods=['GET'])
def get_my_instances():
    file = open("main.tf", "r")
    lines = file.readlines()
    listInstances = []
    for line in lines:
        if line[2:15] == "instance_type":
            line = line.replace(" ", "")
            pos1 = line.find('="')
            pos2 = line.find('"\n')
            line = line[pos1:pos2]
            line = line.replace("=", "")
            line = line.replace('"', '')
            print(line)
            listInstances.append(line)
    print(listInstances)
    return render_template('my_instances.html', listInstances=listInstances)

@app.route("/delete_device/<selected_model>", methods=["GET"])
def deleteDevice(selected_model):
    url = "http://localhost:5000/v1/cloud/aws/delete_device?instance="+selected_model
    requests.post(url)
    return redirect(url_for('all_devices'))

def getDevices():
    url = "http://localhost:5000/v1/cloud/aws/all_instances"
    models = requests.get(url)
    array_devices = models.json()
    return array_devices

def getConsoByDevice(device):
    url = "http://localhost:5000/v1/cloud/aws/get_impact?instance="+device+"&verbose=false"
    temp = requests.get(url)
    conso = temp.json()
    return conso

def makeCategories(array_devices):
    listCat = []
    listCat.append(array_devices[0][0:2])
    cpt = 0
    for d in array_devices:
        if (d[0:2] != listCat[cpt]):
            listCat.append(d[0:2])
            cpt += 1
    return listCat