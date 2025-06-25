function transformIdentityData(data) {
    if (data.name === "Default Admin") {
        data.type = "Admin";
    } else if (data.type === "Default") {
        data.type = "Identity";
    }
    return data;
}

// 在數據加載時應用轉換
page.filterObject.transform = transformIdentityData; 