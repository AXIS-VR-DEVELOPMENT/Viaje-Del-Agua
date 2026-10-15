using UnityEngine;

public class LevitatingMaterialController : MonoBehaviour
{

    public MeshRenderer stationaryModel;
    public MeshRenderer floatingModel;

    public Rigidbody parentRigidbody;

    private void Awake()
    {
        if (!parentRigidbody) parentRigidbody=GetComponent<Rigidbody>();        
    }
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        floatingModel.enabled = false;
        stationaryModel.enabled = true;

    }

    // Update is called once per frame
    void Update()
    {
        
    }


    public void SetLevitation(bool state)
    {
        if (!floatingModel || !stationaryModel) return;
        floatingModel.enabled = state;
        stationaryModel.enabled = !state;
        parentRigidbody.useGravity = !state;
        parentRigidbody.isKinematic = state;
    }
}
