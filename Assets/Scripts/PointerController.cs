using UnityEngine;

public class PointerController : MonoBehaviour
{
    public LayerMask interactionsLayer;

    [SerializeField]
    private bool _isPointerActivated;

    public Canvas pointerUI;

    private Transform _pointerTransform;
    private RaycastHit[] _objectsHit;

    [SerializeField]
    private float _laserMaxDistance = 20f;

    [Header("Axis Constraints (Para el objeto agarrado)")]
    public bool lockX = false;
    public bool lockY = true;  // Por defecto bloqueamos la altura para que no suba/baje
    public bool lockZ = false;

    // --- Variables de Estado para el Agarre ---
    private GameObject _grabbedObject;
    private LevitatingMaterialController _floatingScript;
    private float _grabDistance;
    private Vector3 _initialGrabPosition;

    private OVRInput.Controller _activeController = OVRInput.Controller.Touch;

    #region UNITY_CALLBACKS
    private void Awake()
    {
        if (!_pointerTransform) _pointerTransform = this.transform;
    }

    void Update()
    {
        if (_isPointerActivated)
        {
            ActivatePointerRay();

            // Si tenemos un objeto agarrado, lo movemos aquí
            if (_grabbedObject != null)
            {
                HandleGrabbedObject();
            }
        }
    }
    #endregion

    #region CALLBACKS
    public void StartPointer(bool isGrabbed)
    {
        _isPointerActivated = isGrabbed;
        if (!isGrabbed && _grabbedObject != null)
        {
            ReleaseObject();
        }
    }

    private void ActivatePointerRay()
    {
        if (!_pointerTransform) return;

        Vector3 rayOriginPosition = _pointerTransform.position;
        Vector3 direction = _pointerTransform.up; 

        _objectsHit = Physics.RaycastAll(rayOriginPosition, direction, _laserMaxDistance, interactionsLayer);
        Debug.DrawRay(rayOriginPosition, direction * _laserMaxDistance, Color.blue);

        // Solo procesamos nuevos impactos si NO tenemos un objeto agarrado
        if (_grabbedObject == null)
        {
            RayInteractionHandler();
        }
    }

    private void RayInteractionHandler()
    {
        foreach (RaycastHit hit in _objectsHit)
        {
            switch (hit.collider.tag)
            {
                case "UI":
                    pointerUI.transform.position = hit.point;
                    Quaternion lookToTarget = Quaternion.LookRotation(hit.normal.normalized);
                    pointerUI.transform.rotation = lookToTarget;
                    break;

                case "GrabbableObject":
                    if (OVRInput.GetDown(OVRInput.Button.PrimaryIndexTrigger,_activeController))
                    {
                        // 1. Guardar la referencia del objeto
                        _grabbedObject = hit.collider.gameObject;

                        // 2. Obtener la distancia desde el control hasta el centro del objeto (evita saltos)
                        _grabDistance = Vector3.Distance(_pointerTransform.position, _grabbedObject.transform.position);

                        // 3. Guardar la posición inicial para bloquear ejes
                        _initialGrabPosition = _grabbedObject.transform.position;

                        // 4. Activar levitación
                        _floatingScript = _grabbedObject.GetComponent<LevitatingMaterialController>();
                        if (_floatingScript != null) _floatingScript.SetLevitation(true);
                    }
                    break;
            }
        }
    }

    private void HandleGrabbedObject()
    {
        // Soltar objeto
        if (OVRInput.GetUp(OVRInput.Button.PrimaryIndexTrigger,_activeController))
        {
            ReleaseObject();
            return;
        }

        // Mover objeto mientras se mantiene el gatillo
        if (OVRInput.Get(OVRInput.Button.PrimaryIndexTrigger,_activeController))
        {
            // Calculamos la posición objetivo basada en la distancia fija
            Vector3 targetPosition = _pointerTransform.position + (_pointerTransform.up * _grabDistance);

            // Aplicamos los bloqueos de eje (reemplazando por la posición original si está bloqueado)
            if (lockX) targetPosition.x = _initialGrabPosition.x;
            if (lockY) targetPosition.y = _initialGrabPosition.y;
            if (lockZ) targetPosition.z = _initialGrabPosition.z;

            _grabbedObject.transform.position = targetPosition;
        }
    }

    private void ReleaseObject()
    {
        if (_floatingScript != null)
        {
            _floatingScript.SetLevitation(false);
        }
        _grabbedObject = null;
        _floatingScript = null;
    }
    #endregion
}